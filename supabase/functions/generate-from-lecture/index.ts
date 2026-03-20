// Supabase Edge Function:
// 1) Validate user-scoped PDF path in Storage bucket `lectures`
// 2) Download PDF bytes
// 3) Call Gemini multimodal generateContent
// 4) Return strict JSON: { summary, flashcards, quiz }

declare const Deno: {
  serve: (handler: (req: Request) => Response | Promise<Response>) => void;
  env: { get(key: string): string | undefined };
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;
const MAX_PDF_BYTES = 20 * 1024 * 1024; // 20 MiB inline_data safety limit
const DEFAULT_MAX_FLASHCARDS = 16;
const DEFAULT_MAX_MCQ = 8;
const DEFAULT_MAX_FILL = 6;

interface GenerateLectureRequest {
  storage_path: string;
  task?: "all" | "summary" | "flashcards" | "quiz";
  language?: string;
  difficulty?: "easy" | "medium" | "hard";
  max_flashcards?: number;
  max_multiple_choice?: number;
  max_fill_in_blank?: number;
  allow_async_job?: boolean;
}

interface FlashcardItem {
  term: string;
  definition: string;
}

interface MultipleChoiceItem {
  question: string;
  options: string[];
  correct_index: number;
  explanation: string;
}

interface FillInBlankItem {
  sentence: string;
  answer: string;
  explanation: string;
}

interface LectureResult {
  summary: string;
  flashcards: FlashcardItem[];
  quiz: {
    multiple_choice: MultipleChoiceItem[];
    fill_in_blank: FillInBlankItem[];
  };
}

type LectureTask = "all" | "summary" | "flashcards" | "quiz";

function clamp(n: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, n));
}

async function getUserIdFromAuth(input: {
  supabaseUrl: string;
  supabaseAnon: string;
  authHeader: string | null;
}): Promise<string | null> {
  if (!input.authHeader || !/^Bearer\s+.+/i.test(input.authHeader)) {
    return null;
  }
  const resp = await fetch(`${input.supabaseUrl}/auth/v1/user`, {
    method: "GET",
    headers: {
      Authorization: input.authHeader,
      apikey: input.supabaseAnon,
    },
  });
  if (!resp.ok) {
    return null;
  }
  const user = await resp.json();
  const userId = typeof user?.id === "string" ? user.id : null;
  return userId && userId.length > 0 ? userId : null;
}

function toBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    const sub = bytes.subarray(i, i + chunk);
    binary += String.fromCharCode(...sub);
  }
  return btoa(binary);
}

function text(v: unknown): string {
  return typeof v === "string" ? v.trim() : "";
}

function isStringArray(v: unknown, len?: number): v is string[] {
  return Array.isArray(v) && v.every((x) => typeof x === "string") && (len == null || v.length === len);
}

function validateLectureResult(raw: unknown, task: LectureTask): LectureResult | null {
  if (!raw || typeof raw !== "object") return null;
  const obj = raw as Record<string, unknown>;
  const summary = taskIncludes(task, "summary") ? text(obj.summary) : text(obj.summary);
  const flashRaw = Array.isArray(obj.flashcards) ? obj.flashcards : [];
  const quizRaw = obj.quiz && typeof obj.quiz === "object" ? obj.quiz as Record<string, unknown> : null;
  if (taskIncludes(task, "summary") && !summary) return null;
  if (taskIncludes(task, "quiz") && !quizRaw) return null;

  const flashcards: FlashcardItem[] = flashRaw
    .map((item) => {
      const r = item && typeof item === "object" ? item as Record<string, unknown> : null;
      if (!r) return null;
      const term = text(r.term);
      const definition = text(r.definition);
      if (!term || !definition) return null;
      return { term, definition };
    })
    .filter((x): x is FlashcardItem => x !== null);

  const mcRaw = quizRaw && Array.isArray(quizRaw.multiple_choice) ? quizRaw.multiple_choice : [];
  const fbRaw = quizRaw && Array.isArray(quizRaw.fill_in_blank) ? quizRaw.fill_in_blank : [];

  const multipleChoice: MultipleChoiceItem[] = mcRaw
    .map((item) => {
      const r = item && typeof item === "object" ? item as Record<string, unknown> : null;
      if (!r) return null;
      const question = text(r.question);
      const explanation = text(r.explanation);
      const options = isStringArray(r.options, 4) ? r.options.map((o) => o.trim()) : [];
      const correctIndex = typeof r.correct_index === "number" ? r.correct_index : Number.NaN;
      if (!question || !explanation || options.some((o) => !o) || !Number.isInteger(correctIndex)) return null;
      if (correctIndex < 0 || correctIndex > 3) return null;
      return {
        question,
        options,
        correct_index: correctIndex,
        explanation,
      };
    })
    .filter((x): x is MultipleChoiceItem => x !== null);

  const fillInBlank: FillInBlankItem[] = fbRaw
    .map((item) => {
      const r = item && typeof item === "object" ? item as Record<string, unknown> : null;
      if (!r) return null;
      const sentence = text(r.sentence);
      const answer = text(r.answer);
      const explanation = text(r.explanation);
      if (!sentence || !answer || !explanation) return null;
      return { sentence, answer, explanation };
    })
    .filter((x): x is FillInBlankItem => x !== null);

  if (taskIncludes(task, "flashcards") && flashcards.length === 0) return null;
  if (taskIncludes(task, "quiz") && (multipleChoice.length === 0 && fillInBlank.length === 0)) return null;

  return {
    summary: summary || "",
    flashcards,
    quiz: {
      multiple_choice: multipleChoice,
      fill_in_blank: fillInBlank,
    },
  };
}

function taskIncludes(task: LectureTask, section: "summary" | "flashcards" | "quiz"): boolean {
  if (task === "all") return true;
  return task === section;
}

function normalizeResultForTask(result: LectureResult, task: LectureTask): LectureResult {
  return {
    summary: taskIncludes(task, "summary") ? result.summary : "",
    flashcards: taskIncludes(task, "flashcards") ? result.flashcards : [],
    quiz: taskIncludes(task, "quiz")
      ? result.quiz
      : { multiple_choice: [], fill_in_blank: [] },
  };
}

function buildSystemPrompt(input: {
  task: LectureTask;
  language: string;
  difficulty: string;
  maxFlashcards: number;
  maxMcq: number;
  maxFill: number;
}): string {
  const requestedSectionText = input.task === "all"
    ? "summary + flashcards + quiz"
    : input.task;
  return `You are an educational content extractor for lecture slides.

Output MUST be a single JSON object with exactly these top-level keys:
- "summary": string
- "flashcards": array of {"term": string, "definition": string}
- "quiz": object with:
  - "multiple_choice": array of {"question": string, "options": string[4], "correct_index": number (0-3), "explanation": string}
  - "fill_in_blank": array of {"sentence": string, "answer": string, "explanation": string}

Rules:
- Return ONLY valid JSON. No markdown, no prose, no code fences.
- Requested output section: ${requestedSectionText}
- Use language: ${input.language}
- Difficulty level: ${input.difficulty}
- Keep technical terms accurate and avoid hallucinations.
- summary should be concise and exam-oriented.
- Create 8-${input.maxFlashcards} flashcards unless source is too short.
- Create 4-${input.maxMcq} multiple-choice questions.
- Create 2-${input.maxFill} fill-in-blank questions.
- For multiple_choice, options must be exactly 4 and correct_index must match the right option index.
- If source quality is low, reduce quantity but keep JSON schema valid.`;
}

async function consumeQuota(input: {
  supabaseUrl: string;
  supabaseAnon: string;
  authHeader: string;
  dailyLimit: number;
}): Promise<boolean> {
  const rpcResp = await fetch(`${input.supabaseUrl}/rest/v1/rpc/consume_lecture_quota`, {
    method: "POST",
    headers: {
      Authorization: input.authHeader,
      apikey: input.supabaseAnon,
      "Content-Type": "application/json",
      Prefer: "return=representation",
    },
    body: JSON.stringify({ p_daily_limit: input.dailyLimit }),
  });
  if (!rpcResp.ok) {
    return false;
  }
  const value = await rpcResp.json();
  return value === true;
}

async function enqueueLectureJob(input: {
  supabaseUrl: string;
  supabaseAnon: string;
  authHeader: string;
  userId: string;
  body: GenerateLectureRequest;
}): Promise<string | null> {
  const payload = {
    user_id: input.userId,
    storage_path: input.body.storage_path,
    status: "pending",
    language: input.body.language ?? null,
    difficulty: input.body.difficulty ?? null,
    max_flashcards: input.body.max_flashcards ?? null,
    max_multiple_choice: input.body.max_multiple_choice ?? null,
    max_fill_in_blank: input.body.max_fill_in_blank ?? null,
  };
  const resp = await fetch(`${input.supabaseUrl}/rest/v1/lecture_jobs`, {
    method: "POST",
    headers: {
      Authorization: input.authHeader,
      apikey: input.supabaseAnon,
      "Content-Type": "application/json",
      Prefer: "return=representation",
    },
    body: JSON.stringify(payload),
  });
  if (!resp.ok) return null;
  const rows = await resp.json();
  const jobId = Array.isArray(rows) && rows.length > 0 ? String(rows[0].id ?? "") : "";
  return jobId || null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), {
        status: 405,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = (await req.json()) as GenerateLectureRequest;
    const task: LectureTask = (body.task === "summary" || body.task === "flashcards" || body.task === "quiz")
      ? body.task
      : "all";
    const storagePath = (body.storage_path ?? "").trim();
    if (!storagePath) {
      return new Response(JSON.stringify({ error: "storage_path is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (!storagePath.toLowerCase().endsWith(".pdf")) {
      return new Response(JSON.stringify({ error: "Only PDF files are supported" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnon = Deno.env.get("SUPABASE_ANON_KEY");
    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (!supabaseUrl || !supabaseAnon || !geminiKey) {
      return new Response(JSON.stringify({ error: "Missing runtime secrets" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const authHeader = req.headers.get("authorization");
    const userId = await getUserIdFromAuth({ supabaseUrl, supabaseAnon, authHeader });
    if (!userId) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (!storagePath.startsWith(`${userId}/`)) {
      return new Response(JSON.stringify({ error: "Forbidden storage_path" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const quotaLimit = clamp(Number(Deno.env.get("LECTURE_DAILY_LIMIT") ?? "20"), 1, 200);
    const quotaAllowed = await consumeQuota({
      supabaseUrl,
      supabaseAnon,
      authHeader: authHeader ?? "",
      dailyLimit: quotaLimit,
    });
    if (!quotaAllowed) {
      return new Response(JSON.stringify({ error: "Daily quota reached", daily_limit: quotaLimit }), {
        status: 429,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const fileResp = await fetch(
      `${supabaseUrl}/storage/v1/object/lectures/${encodeURI(storagePath)}`,
      {
        headers: {
          Authorization: authHeader ?? "",
          apikey: supabaseAnon,
        },
      }
    );
    if (!fileResp.ok) {
      const detail = await fileResp.text();
      return new Response(JSON.stringify({ error: "Failed to download PDF from storage", detail }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const contentType = fileResp.headers.get("content-type") ?? "";
    if (!contentType.toLowerCase().includes("application/pdf")) {
      return new Response(JSON.stringify({ error: "File is not a PDF" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const bytes = new Uint8Array(await fileResp.arrayBuffer());
    if (bytes.length === 0) {
      return new Response(JSON.stringify({ error: "PDF is empty" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (bytes.length > MAX_PDF_BYTES) {
      if (body.allow_async_job === true) {
        const jobId = await enqueueLectureJob({
          supabaseUrl,
          supabaseAnon,
          authHeader: authHeader ?? "",
          userId,
          body,
        });
        if (jobId) {
          return new Response(
            JSON.stringify({
              status: "queued",
              job_id: jobId,
              reason: "PDF too large for synchronous mode; queued for async processing",
              size_bytes: bytes.length,
              max_sync_bytes: MAX_PDF_BYTES,
            }),
            {
              status: 202,
              headers: { ...corsHeaders, "Content-Type": "application/json" },
            }
          );
        }
      }
      return new Response(
        JSON.stringify({
          error: "PDF too large for synchronous processing",
          max_bytes: MAX_PDF_BYTES,
          size_bytes: bytes.length,
          hint: "Set allow_async_job=true to queue this file in lecture_jobs.",
        }),
        {
          status: 413,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const language = text(body.language) || "繁體中文";
    const difficulty = text(body.difficulty) || "medium";
    const maxFlashcards = clamp(Number(body.max_flashcards ?? DEFAULT_MAX_FLASHCARDS), 6, 24);
    const maxMcq = clamp(Number(body.max_multiple_choice ?? DEFAULT_MAX_MCQ), 3, 12);
    const maxFill = clamp(Number(body.max_fill_in_blank ?? DEFAULT_MAX_FILL), 2, 10);

    const systemPrompt = buildSystemPrompt({
      task,
      language,
      difficulty,
      maxFlashcards,
      maxMcq,
      maxFill,
    });
    const userPrompt = `Analyze this lecture PDF and produce structured study material.`;
    const inlineData = toBase64(bytes);

    const runGemini = async (temperature: number): Promise<Response> =>
      await fetch(`${GEMINI_URL}?key=${geminiKey}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                { text: userPrompt },
                {
                  inline_data: {
                    mime_type: "application/pdf",
                    data: inlineData,
                  },
                },
              ],
            },
          ],
          systemInstruction: { parts: [{ text: systemPrompt }] },
          generationConfig: {
            temperature,
            responseMimeType: "application/json",
          },
        }),
      });

    let geminiResponse = await runGemini(0.4);
    if (!geminiResponse.ok) {
      const detail = await geminiResponse.text();
      return new Response(JSON.stringify({ error: "Gemini request failed", detail }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let data = await geminiResponse.json();
    let textPart = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    let parsed: LectureResult | null = null;
    if (typeof textPart === "string") {
      try {
        parsed = validateLectureResult(JSON.parse(textPart), task);
      } catch {
        parsed = null;
      }
    }

    if (!parsed) {
      geminiResponse = await runGemini(0.2);
      if (!geminiResponse.ok) {
        const detail = await geminiResponse.text();
        return new Response(JSON.stringify({ error: "Gemini retry failed", detail }), {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      data = await geminiResponse.json();
      textPart = data?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (typeof textPart === "string") {
        try {
          parsed = validateLectureResult(JSON.parse(textPart), task);
        } catch {
          parsed = null;
        }
      }
    }

    if (!parsed) {
      return new Response(
        JSON.stringify({
          error: "Invalid JSON from Gemini",
          raw: typeof textPart === "string" ? textPart : null,
        }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    return new Response(JSON.stringify(normalizeResultForTask(parsed, task)), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(
      JSON.stringify({ error: "Internal error", message: String(e) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
