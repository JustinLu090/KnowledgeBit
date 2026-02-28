// Supabase Edge Function: 根據使用者輸入的主題，用 Google Gemini 產生「多張」單字卡，歸於同一單字集。
// API Key 請在 Supabase Dashboard 設定 Secret: GEMINI_API_KEY
declare const Deno: {
  serve: (handler: (req: Request) => Response | Promise<Response>) => void;
  env: { get(key: string): string | undefined };
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface RequestBody {
  prompt: string;
  /** 單字集內已存在的單字（小寫），AI 會避免重複產生 */
  existing_words?: string[];
}

interface GeneratedCardItem {
  word: string;
  definition: string;
  example_sentence: string;
}

const GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

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
    const prompt = body?.prompt?.trim();
    if (!prompt) {
      return new Response(
        JSON.stringify({ error: "prompt is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const existingWords = Array.isArray(body?.existing_words)
      ? body.existing_words.filter((w) => typeof w === "string" && w.trim().length > 0).map((w) => w.trim().toLowerCase())
      : [];
    const existingHint =
      existingWords.length > 0
        ? `\n\n重要：以下單字已在單字集中，請「不要」再產生這些單字（避免重複）：${existingWords.join(", ")}。請只產生「尚未出現」的單字。`
        : "";

    const systemPrompt = `你是一個單字卡助手。根據使用者給的「主題」（例如：餐廳用餐、旅行、程式用語），產生「多張」獨立的單字卡，每張卡一個單字/詞。
回傳必須是「一個 JSON 陣列」，陣列中每個元素代表一張單字卡，且只包含以下三個欄位（不要多餘的 markdown 程式碼區塊或說明）：
- "word": 單字或詞（英文或目標語言，簡短）
- "definition": 中文或使用者語言的定義/解釋，簡潔
- "example_sentence": 一句例句（可含中文翻譯），幫助記憶

請依主題產出 5～10 張單字卡，品質優先。${existingHint}

回傳格式範例：
[{"word":"vocabulary","definition":"詞彙","example_sentence":"I need to expand my vocabulary. (我需要擴充詞彙。)"},{"word":"..."}]`;

    const response = await fetch(`${GEMINI_URL}?key=${apiKey}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: `主題：${prompt}` }] }],
        systemInstruction: { parts: [{ text: systemPrompt }] },
        generationConfig: {
          temperature: 0.6,
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

    const parsed = JSON.parse(textPart) as GeneratedCardItem[];
    if (!Array.isArray(parsed) || parsed.length === 0) {
      return new Response(
        JSON.stringify({ error: "Invalid or empty cards array", raw: textPart }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const existingSet = new Set(existingWords);
    const seen = new Set<string>();
    const cards = parsed
      .map((item) => ({
        word: typeof item.word === "string" ? item.word.trim() : "",
        definition: typeof item.definition === "string" ? item.definition.trim() : "",
        example_sentence: typeof item.example_sentence === "string" ? item.example_sentence.trim() : "",
      }))
      .filter((c) => c.word.length > 0)
      .filter((c) => {
        const key = c.word.toLowerCase();
        if (existingSet.has(key) || seen.has(key)) return false;
        seen.add(key);
        return true;
      });

    return new Response(
      JSON.stringify({ cards }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: "Internal error", message: String(e) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
