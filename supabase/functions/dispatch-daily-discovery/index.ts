const defaultWorkflowFile = "daily_discovery.yml";
const defaultWorkflowRef = "main";

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}

function clampLimit(raw: unknown): number {
  const parsed = Number.parseInt(String(raw ?? "500"), 10);
  if (Number.isNaN(parsed)) return 500;
  return Math.min(1000, Math.max(1, parsed));
}

function clampMinQuotesGoal(raw: unknown): number {
  const parsed = Number.parseInt(String(raw ?? "50"), 10);
  if (Number.isNaN(parsed)) return 50;
  return Math.min(250, Math.max(0, parsed));
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const dispatchToken = Deno.env.get("DISCOVERY_DISPATCH_TOKEN")?.trim() ?? "";
  if (dispatchToken.length > 0) {
    const authorization = request.headers.get("Authorization")?.trim() ?? "";
    if (authorization != `Bearer ${dispatchToken}`) {
      return jsonResponse({ error: "unauthorized" }, 401);
    }
  }

  const githubToken = Deno.env.get("GITHUB_TOKEN")?.trim() ?? "";
  const githubRepository = Deno.env.get("GITHUB_REPOSITORY")?.trim() ?? "";
  const workflowFile =
    Deno.env.get("DISCOVERY_WORKFLOW_FILE")?.trim() || defaultWorkflowFile;
  const workflowRef =
    Deno.env.get("DISCOVERY_WORKFLOW_REF")?.trim() || defaultWorkflowRef;

  if (githubToken.length === 0 || githubRepository.length === 0) {
    return jsonResponse(
      {
        error: "missing_configuration",
        message:
          "GITHUB_TOKEN and GITHUB_REPOSITORY must both be set for dispatch-daily-discovery.",
      },
      500,
    );
  }

  let payload: Record<string, unknown> = {};
  try {
    payload = await request.json();
  } catch (_) {
    payload = {};
  }

  const limit = clampLimit(payload["limit"]);
  const minQuotesGoal = clampMinQuotesGoal(payload["min_quotes_goal"]);
  const trigger = String(payload["trigger"] ?? "manual").trim() || "manual";

  const response = await fetch(
    `https://api.github.com/repos/${githubRepository}/actions/workflows/${workflowFile}/dispatches`,
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${githubToken}`,
        "Accept": "application/vnd.github+json",
        "Content-Type": "application/json",
        "X-GitHub-Api-Version": "2022-11-28",
      },
      body: JSON.stringify({
        ref: workflowRef,
        inputs: {
          limit: String(limit),
          min_quotes_goal: String(minQuotesGoal),
          trigger,
        },
      }),
    },
  );

  if (!response.ok) {
    const responseText = await response.text();
    return jsonResponse(
      {
        error: "github_dispatch_failed",
        status: response.status,
        body: responseText,
      },
      502,
    );
  }

  return jsonResponse({
    ok: true,
    repository: githubRepository,
    workflow: workflowFile,
    ref: workflowRef,
    limit,
    min_quotes_goal: minQuotesGoal,
    trigger,
  });
});
