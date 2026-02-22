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
  explanation: string;
}

const GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";
const MAX_WORDS = 15;

/** 檢測單字清單是否主要為韓文（含韓文音節或初聲中聲終聲） */
function isKoreanWordList(words: { word: string }[]): boolean {
  const hangulRange = /[\uAC00-\uD7A3\u1100-\u11FF]/;
  const withHangul = words.filter((w) => hangulRange.test(w.word));
  return withHangul.length >= Math.max(1, Math.ceil(words.length / 2));
}

const SYSTEM_PROMPT_DEFAULT = `你是一個出題助手。根據給定的單字清單，產生「挖空填空」選擇題。

每題規則：
1. 一句話中用 \`___\` 表示要填的單字位置（僅一個 \`___\`）。
2. 正確答案必須是清單中的單字。
3. 四個選項：一個正確答案 + 三個干擾項（與正確答案詞性/情境相近），選項順序請打亂。
4. **選項大小寫**：選項是用來填入句子中間的，因此每個選項的首字母必須為小寫（除非該單字本身是專有名詞，如 Monday、Paris），以確保填入後句子語法與視覺連貫。
5. **詳解（explanation）**：每題必須包含 "explanation" 欄位，內容需涵蓋：(a) 為什麼該選項是正確答案；(b) 其他干擾項為什麼不適合（若適用）；(c) 相關語法或單字補充。使用簡潔中文撰寫。

回傳必須是「一個 JSON 陣列」，每個元素包含以下四個欄位（不要 markdown 程式碼區塊或說明）：
- "sentence_with_blank": 含 \`___\` 的句子（字串）
- "correct_answer": 正確單字（字串，填在句中時應為小寫除非專有名詞）
- "options": 長度為 4 的字串陣列，四個選項首字母皆小寫（專有名詞除外），包含正確答案與三個干擾項
- "explanation": 詳解（字串），說明正確答案為何、干擾項為何錯誤、相關語法或單字補充

請依清單產出 3～5 題即可，每題對應不同單字。回傳格式範例：
[{"sentence_with_blank":"He decided to _______ the offer after much thought.","correct_answer":"accept","options":["accept","reject","ignore","postpone"],"explanation":"在此語境中，'accept'（接受）最符合邏輯。'reject' 是拒絕，'ignore' 是無視，'postpone' 是延期。"}]`;

const SYSTEM_PROMPT_KOREAN = `你是一個出題助手。根據給定的「韓文」單字清單，產生「挖空填空」選擇題。測驗目標語言為韓文。

每題規則：
1. **題目與選項全韓文**：sentence_with_blank（題目句子）與 options（四個選項）必須全部使用韓文撰寫。嚴禁在題目或選項中出現中文（除非該題目本身是翻譯題）。
2. 一句話中用 \`___\` 表示要填的單字位置（僅一個 \`___\`）。
3. 正確答案必須是清單中的單字。
4. 四個選項：一個正確答案 + 三個干擾項（與正確答案詞性/情境相近），選項順序請打亂。
5. **格式**：韓文無首字母大小寫問題，但請確保語助詞、受詞助詞（조사）使用正確，使句子自然通順。
6. **詳解（explanation）**：每題的 "explanation" 欄位必須使用「繁體中文」撰寫，內容需包含：(a) 該韓文句子的中文翻譯；(b) 正確選項的語法或詞義解釋；(c) 其他干擾項的簡單說明（為何不適合）。

回傳必須是「一個 JSON 陣列」，每個元素包含以下四個欄位（不要 markdown 程式碼區塊或說明）：
- "sentence_with_blank": 含 \`___\` 的韓文句子（字串）
- "correct_answer": 正確韓文單字（字串）
- "options": 長度為 4 的韓文字串陣列，包含正確答案與三個干擾項，皆為韓文
- "explanation": 詳解（字串），繁體中文：韓文句中譯、正確選項語法解釋、干擾項簡述

請依清單產出 3～5 題即可，每題對應不同單字。回傳格式範例：
[{"sentence_with_blank":"오늘 제 주요 _______는 이 보고서를 완성하는 것입니다.","correct_answer":"업무","options":["업무","취미","오락","휴식"],"explanation":"這句的意思是『今天我的主要任務是完成這份報告』。'업무' 意思是工作、任務，最符合語境。'취미' 是興趣，'오락' 是娛樂，'휴식' 則是休息。"}]`;

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
    const useKorean = isKoreanWordList(limited);
    const systemPrompt = useKorean ? SYSTEM_PROMPT_KOREAN : SYSTEM_PROMPT_DEFAULT;
    const listLabel = useKorean ? "韓文單字清單" : "單字清單";

    const response = await fetch(`${GEMINI_URL}?key=${apiKey}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: `${listLabel}：\n${wordsForPrompt}` }] }],
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
        explanation: typeof (q as QuizQuestionItem).explanation === "string"
          ? String((q as QuizQuestionItem).explanation).trim()
          : "",
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
