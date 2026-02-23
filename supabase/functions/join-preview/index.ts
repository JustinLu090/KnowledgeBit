// Edge Function: 邀請連結網頁預覽（供 LINE / 瀏覽器點開時顯示「XXX 邀請你加入 KnowledgeBit」並提供開 App 按鈕）
// 部署後可將網域 knowledgebit.io 的 /join/:code 指向此 Function（或透過反向代理）

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const pathMatch = url.pathname.match(/\/join\/([A-Za-z0-9]+)$/);
  const code = (pathMatch?.[1] ?? url.searchParams.get("code") ?? "").trim();

  if (!code) {
    return new Response(htmlPage("邀請連結無效", "請使用 App 內分享的完整連結。", null), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "text/html; charset=utf-8" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseKey) {
    return new Response(htmlPage("暫時無法載入", "請稍後再試。", code), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "text/html; charset=utf-8" },
    });
  }

  const supabase = createClient(supabaseUrl, supabaseKey);
  const { data: rows } = await supabase.rpc("get_profile_by_invite_code", { code: code.toUpperCase() });
  const displayName = rows?.[0]?.display_name ?? "好友";

  return new Response(htmlPage(`${displayName} 邀請你加入 KnowledgeBit`, "點擊下方按鈕開啟 App 發送好友請求。", code), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "text/html; charset=utf-8" },
  });
});

function htmlPage(title: string, message: string, inviteCode: string | null): string {
  const appScheme = inviteCode ? `knowledgebit://join/${inviteCode}` : "knowledgebit://";
  const webFallback = inviteCode ? `https://knowledgebit.io/join/${inviteCode}` : "#";
  return `<!DOCTYPE html>
<html lang="zh-Hant">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(title)}</title>
  <meta property="og:title" content="${escapeHtml(title)}">
  <meta property="og:description" content="${escapeHtml(message)}">
  <style>
    * { box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 0; padding: 24px; min-height: 100vh; display: flex; flex-direction: column; align-items: center; justify-content: center; background: #f2f2f7; color: #1c1c1e; }
    h1 { font-size: 1.5rem; margin: 0 0 12px; text-align: center; }
    p { font-size: 1rem; color: #3a3a3c; text-align: center; margin: 0 0 24px; }
    a { display: inline-block; padding: 14px 28px; background: #007AFF; color: #fff; text-decoration: none; border-radius: 12px; font-weight: 600; }
  </style>
</head>
<body>
  <h1>${escapeHtml(title)}</h1>
  <p>${escapeHtml(message)}</p>
  <a href="${escapeHtml(appScheme)}">開啟 KnowledgeBit</a>
</body>
</html>`;
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}
