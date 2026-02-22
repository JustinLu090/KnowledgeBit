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
  /** 選填：若傳入則優先作為目標語言指示給 AI（例如 "韓文"、"日文"、"英文"） */
  word_set?: { language?: string };
}

interface QuizQuestionItem {
  sentence_with_blank: string;
  correct_answer: string;
  options: string[];
  explanation: string;
}

const GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";
const MAX_WORDS = 15;

type DetectedLang = "ko" | "ja" | "en";

/** 根據單字內容辨識單字集主要語言，供 prompt 傳遞目標語言用 */
function detectWordSetLanguage(words: { word: string }[]): DetectedLang {
  const hangul = /[\uAC00-\uD7A3\u1100-\u11FF]/;
  const hiraganaKatakana = /[\u3040-\u309F\u30A0-\u30FF]/;
  const cjkKanji = /[\u4E00-\u9FFF\u3400-\u4DBF]/; // 漢字（日文常用），與中文共用
  let ko = 0, ja = 0;
  for (const w of words) {
    if (hangul.test(w.word)) ko++;
    if (hiraganaKatakana.test(w.word) || cjkKanji.test(w.word)) ja++;
  }
  const n = words.length;
  const half = Math.max(1, Math.ceil(n / 2));
  if (ko >= half) return "ko";
  if (ja >= half) return "ja";
  return "en";
}

const LANG_LABEL: Record<DetectedLang, string> = {
  ko: "韓文",
  ja: "日文",
  en: "英文",
};

const PLACEHOLDER = "_______";

/** 將被拆成多段的底線（如 _______ _______ _）正規化為單一 _______，避免 UI 顯示異常 */
function normalizePlaceholder(sentence: string): string {
  return sentence.replace(/_+\s+_+(\s+_+)*/g, PLACEHOLDER);
}

const SYSTEM_PROMPT = `你是一個出題助手。根據給定的單字清單與「目標語言」指示，產生「挖空填空」選擇題。

## 語言一致性（Language Matching）
- 請依傳入的目標語言出題：**題目句子（sentence_with_blank）與四個選項（options）必須與單字集的目標語言完全一致**。
- 若目標語言為日文，則整句題目與選項皆為日文；若為韓文則全為韓文；若為英文則全為英文，以此類推。題目與選項中不得混入其他語言（除非該題為翻譯題）。

## 統一空格格式（Unified Placeholder）— 強制遵守
- 題目中的挖空處**嚴格且唯一**使用 **7 個連續底線**：\`_______\`（中間不得有任何其他字元）。
- **禁止**在底線之間或挖空處插入：空白字元、換行符號、多餘底線或任何符號。整段挖空必須是連續的 \`_______\`，不可拆成多段（例如不可出現 \`_______ _______ _\` 或換行切斷）。
- 每題僅有一個挖空，且該挖空必須以單一連續的 \`_______\` 呈現，確保前端 UI 能正確顯示。
- 範例（韓文）：\`매일 아침 8시에 _______ 해서 하루를 시작합니다.\`（空格必須完整、不被切斷）。
- **若目標語言為英文**：出現在句子中間的選項必須為小寫（專有名詞如 Monday、Paris 除外），以確保填入後語法與視覺連貫。
- 非英文語言（如日文、韓文）無首字母大小寫問題，但請確保助詞、語尾等用法正確、句子自然。

## 詳解語言規範
- **無論目標語言為何**，\`explanation\`（詳解）欄位請**一律使用繁體中文**撰寫，以便使用者理解。
- 詳解內容應包含：(a) 整句翻譯（將題目句子譯成中文）；(b) 正確答案的語法或詞義說明；(c) 干擾項的排除說明（為何不適合）。

## 出題與回傳
- 正確答案必須來自清單中的單字；四個選項為一個正確答案 + 三個干擾項（與正確答案詞性/情境相近），選項順序請打亂。
- 回傳必須是「一個 JSON 陣列」，每個元素包含以下四個欄位（不要 markdown 程式碼區塊或額外說明）：
  - "sentence_with_blank": 題目句子，挖空處為**單一連續** \`_______\`（字串內禁止對底線分段或換行）
  - "correct_answer": 正確單字（字串）
  - "options": 長度為 4 的字串陣列，與目標語言一致
  - "explanation": 詳解（字串），繁體中文：整句翻譯、正確答案語法點、干擾項排除說明

請依清單產出 3～5 題，每題對應不同單字。

範例（目標語言為韓文時）：
[{"sentence_with_blank":"이번 휴가에는 제주도로 _______을 가기로 했습니다.","correct_answer":"여행","options":["여행","요리","공부","운동"],"explanation":"這句話的意思是『這次假期決定去濟州島旅遊』。'여행'（旅遊）最符合語境。'요리' 是烹飪，'공부' 是學習，'운동' 是運動。"}]`;

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
    const explicitLang = body.word_set?.language != null && String(body.word_set.language).trim() !== ""
      ? String(body.word_set.language).trim()
      : null;
    const detectedLang = detectWordSetLanguage(limited);
    const targetLanguageLabel = explicitLang ?? LANG_LABEL[detectedLang];
    const userMessage = `目標語言：${targetLanguageLabel}\n\n單字清單：\n${wordsForPrompt}`;

    const response = await fetch(`${GEMINI_URL}?key=${apiKey}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: userMessage }] }],
        systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
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
        sentence_with_blank: normalizePlaceholder(String(q.sentence_with_blank).trim()),
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
