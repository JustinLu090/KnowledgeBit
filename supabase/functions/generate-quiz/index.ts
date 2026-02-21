// Supabase Edge Function: 依單字集產生「挖空句 + 四選一」選擇題，供選擇題測驗使用。
// API Key: GEMINI_API_KEY（與 generate-card 相同）
declare const Deno: {
  serve: (handler: (req: Request) => Response | Promise<Response>) => void;
  env: { get(key: string): string | undefined };
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface WordInput {
  word: string;
  definition?: string;
}

interface RequestBody {
  words: WordInput[];
}

interface QuizQuestionItem {
  sentence_with_blank: string;
  correct_answer: string;
  options: string[];
}

const GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";
const MAX_WORDS = 15;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "GEMINI_API_KEY not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const body = (await req.json()) as RequestBody;
    const words = body?.words;
    if (!Array.isArray(words) || words.length < 1) {
      return new Response(
        JSON.stringify({ error: "words array is required and must have at least one item" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const limited = words.slice(0, MAX_WORDS).map((w) => ({
      word: typeof w.word === "string" ? w.word.trim() : "",
      definition: typeof w.definition === "string" ? w.definition.trim() : undefined,
    })).filter((w) => w.word.length > 0);

    if (limited.length < 1) {
      return new Response(
        JSON.stringify({ error: "at least one valid word is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const wordsForPrompt = limited.map((w) => (w.definition ? `${w.word}: ${w.definition}` : w.word)).join("\n");
    const systemPrompt = `你是一個出題助手。根據給定的單字清單，產生「挖空填空」選擇題。
每題規則：
1. 一句話中用 \`___\` 表示要填的單字位置（僅一個 \`___\`）。
2. 正確答案必須是清單中的單字。
3. 四個選項：一個正確答案 + 三個干擾項（與正確答案詞性/情境相近），選項順序請打亂。
回傳必須是「一個 JSON 陣列」，每個元素只包含三個欄位（不要 markdown 程式碼區塊或說明）：
- "sentence_with_blank": 含 \`___\` 的句子（字串）
- "correct_answer": 正確單字（字串）
- "options": 長度為 4 的字串陣列，包含正確答案與三個干擾項

請依清單產出 3～5 題即可，每題對應不同單字。回傳格式範例：
[{"sentence_with_blank":"The ___ is on the table.","correct_answer":"book","options":["pen","book","cup","key"]}]`;

    const response = await fetch(`${GEMINI_URL}?key=${apiKey}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: `單字清單：\n${wordsForPrompt}` }] }],
        systemInstruction: { parts: [{ text: systemPrompt }] },
        generationConfig: {
          temperature: 0.5,
          responseMimeType: "application/json",
        },
      }),
    });

    if (!response.ok) {
      const errText = await response.text();
      return new Response(
        JSON.stringify({ error: "Gemini request failed", detail: errText }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const data = await response.json();
    const textPart = data.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!textPart) {
      return new Response(
        JSON.stringify({ error: "Empty response from Gemini", raw: data }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let parsed: QuizQuestionItem[];
    try {
      parsed = JSON.parse(textPart) as QuizQuestionItem[];
    } catch {
      return new Response(
        JSON.stringify({ error: "Invalid JSON from Gemini", raw: textPart }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!Array.isArray(parsed) || parsed.length === 0) {
      return new Response(
        JSON.stringify({ error: "Invalid or empty questions array", raw: textPart }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const questions = parsed
      .filter((q) => q && Array.isArray(q.options) && q.options.length === 4 &&
        typeof q.sentence_with_blank === "string" && typeof q.correct_answer === "string" &&
        q.options.includes(q.correct_answer))
      .map((q) => ({
        sentence_with_blank: String(q.sentence_with_blank).trim(),
        correct_answer: String(q.correct_answer).trim(),
        options: q.options.map((o) => String(o).trim()),
      }));

    return new Response(
      JSON.stringify({ questions }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: "Internal error", message: String(e) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
