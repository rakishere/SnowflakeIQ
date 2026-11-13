const apiBaseUrl = (
  import.meta.env.VITE_API_BASE_URL ?? "http://localhost:8000"
).replace(/\/$/, "");

export type Cell = string | number | boolean | null;

/** One message in the format Cortex Analyst expects as conversation history. */
export type AnalystMessage = {
  role: "user" | "analyst";
  content: Record<string, unknown>[];
};

export type ChatAnswer = {
  text: string;
  sql: string | null;
  suggestions: string[];
  columns: string[];
  rows: Cell[][];
  truncated: boolean;
  sql_error: string | null;
  message: AnalystMessage;
  request_id: string | null;
};

async function readError(response: Response): Promise<string> {
  try {
    const body: { detail?: unknown } = await response.json();
    if (typeof body.detail === "string") return body.detail;
    if (body.detail) return JSON.stringify(body.detail);
  } catch {
    // Fall through to the generic message below.
  }
  return `Backend returned HTTP ${response.status}`;
}

export async function checkHealth(): Promise<void> {
  const response = await fetch(`${apiBaseUrl}/api/health`);
  if (!response.ok) throw new Error(await readError(response));
}

export async function askQuestion(
  question: string,
  history: AnalystMessage[],
): Promise<ChatAnswer> {
  const response = await fetch(`${apiBaseUrl}/api/chat`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ question, history }),
  });
  if (!response.ok) throw new Error(await readError(response));
  return response.json();
}

export function userMessage(question: string): AnalystMessage {
  return { role: "user", content: [{ type: "text", text: question }] };
}
