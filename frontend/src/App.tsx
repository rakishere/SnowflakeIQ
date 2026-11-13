import { useEffect, useRef, useState } from "react";
import type { FormEvent, KeyboardEvent } from "react";
import { askQuestion, checkHealth, userMessage } from "./api";
import type { AnalystMessage, Cell, ChatAnswer } from "./api";

type Turn =
  | { id: number; kind: "user"; text: string }
  | { id: number; kind: "answer"; answer: ChatAnswer }
  | { id: number; kind: "error"; message: string };

type BackendStatus = "checking" | "ok" | "down";

const STARTER_QUESTIONS = [
  "What questions can I ask?",
  "What metrics are available?",
];

function formatCell(value: Cell): string {
  if (value === null) return "-";
  if (typeof value === "number") return value.toLocaleString();
  return String(value);
}

function ResultTable({ answer }: { answer: ChatAnswer }) {
  if (answer.columns.length === 0) return null;
  return (
    <div className="mt-3">
      <div className="max-h-80 overflow-auto rounded-xl border border-slate-200">
        <table className="min-w-full text-left text-sm">
          <thead className="sticky top-0 bg-slate-100 text-xs uppercase tracking-wide text-slate-600">
            <tr>
              {answer.columns.map((column) => (
                <th className="px-3 py-2 font-semibold" key={column} scope="col">
                  {column}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100 bg-white">
            {answer.rows.map((row, rowIndex) => (
              <tr key={rowIndex}>
                {row.map((cell, cellIndex) => (
                  <td
                    className={`whitespace-nowrap px-3 py-2 text-slate-700 ${
                      typeof cell === "number" ? "text-right tabular-nums" : ""
                    }`}
                    key={cellIndex}
                  >
                    {formatCell(cell)}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="mt-1.5 text-xs text-slate-500">
        {answer.rows.length === 0
          ? "The query returned no rows."
          : `${answer.rows.length} row${answer.rows.length === 1 ? "" : "s"}${
              answer.truncated ? " shown (more rows were cut off)" : ""
            }`}
      </p>
    </div>
  );
}

function AnswerCard({
  answer,
  disabled,
  onSuggestion,
}: {
  answer: ChatAnswer;
  disabled: boolean;
  onSuggestion: (question: string) => void;
}) {
  return (
    <div className="max-w-full rounded-2xl rounded-tl-sm border border-slate-200 bg-white px-4 py-3 shadow-sm">
      {answer.text && (
        <p className="whitespace-pre-wrap leading-7 text-slate-800">
          {answer.text}
        </p>
      )}

      <ResultTable answer={answer} />

      {answer.sql_error && (
        <p className="mt-3 rounded-lg bg-rose-50 px-3 py-2 text-sm text-rose-700">
          The generated query could not be run: {answer.sql_error}
        </p>
      )}

      {answer.sql && (
        <details className="mt-3 text-sm">
          <summary className="cursor-pointer font-medium text-sky-700">
            Show generated SQL
          </summary>
          <pre className="mt-2 overflow-x-auto rounded-lg bg-slate-900 p-3 text-xs leading-5 text-slate-100">
            {answer.sql}
          </pre>
        </details>
      )}

      {answer.suggestions.length > 0 && (
        <div className="mt-3 flex flex-wrap gap-2">
          {answer.suggestions.map((suggestion) => (
            <button
              className="rounded-full border border-sky-200 bg-sky-50 px-3 py-1.5 text-left text-sm text-sky-800 transition hover:bg-sky-100 disabled:opacity-50"
              disabled={disabled}
              key={suggestion}
              onClick={() => onSuggestion(suggestion)}
              type="button"
            >
              {suggestion}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

function App() {
  const [turns, setTurns] = useState<Turn[]>([]);
  const [history, setHistory] = useState<AnalystMessage[]>([]);
  const [input, setInput] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [backend, setBackend] = useState<BackendStatus>("checking");
  const nextId = useRef(1);
  const endOfChat = useRef<HTMLDivElement>(null);

  useEffect(() => {
    let cancelled = false;
    checkHealth()
      .then(() => !cancelled && setBackend("ok"))
      .catch(() => !cancelled && setBackend("down"));
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    endOfChat.current?.scrollIntoView({ behavior: "smooth" });
  }, [turns, isLoading]);

  async function submit(rawQuestion: string) {
    const question = rawQuestion.trim();
    if (!question || isLoading) return;

    setInput("");
    setIsLoading(true);
    setTurns((current) => [
      ...current,
      { id: nextId.current++, kind: "user", text: question },
    ]);

    try {
      const answer = await askQuestion(question, history);
      setTurns((current) => [
        ...current,
        { id: nextId.current++, kind: "answer", answer },
      ]);
      // Only successful exchanges become history, so it always alternates
      // between user and analyst messages.
      setHistory((current) => [
        ...current,
        userMessage(question),
        answer.message,
      ]);
      setBackend("ok");
    } catch (error) {
      const isNetworkError = error instanceof TypeError;
      if (isNetworkError) setBackend("down");
      setTurns((current) => [
        ...current,
        {
          id: nextId.current++,
          kind: "error",
          message: isNetworkError
            ? "Could not reach the backend. Check that it is running on port 8000."
            : error instanceof Error
              ? error.message
              : "Unknown error",
        },
      ]);
    } finally {
      setIsLoading(false);
    }
  }

  function handleSubmit(event: FormEvent) {
    event.preventDefault();
    void submit(input);
  }

  function handleKeyDown(event: KeyboardEvent<HTMLTextAreaElement>) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      void submit(input);
    }
  }

  function startNewChat() {
    setTurns([]);
    setHistory([]);
    setInput("");
  }

  return (
    <div className="mx-auto flex h-screen max-w-4xl flex-col px-4">
      <header className="flex items-center justify-between gap-3 border-b border-slate-200 py-4">
        <div className="flex items-center gap-3">
          <div
            aria-hidden="true"
            className="grid size-10 place-items-center rounded-xl bg-sky-100 text-lg font-bold text-sky-700"
          >
            S
          </div>
          <div>
            <h1 className="text-lg font-bold tracking-tight text-slate-900">
              SnowflakeIQ
            </h1>
            <p className="text-sm text-slate-500">
              Ask questions about your sales data in plain English
            </p>
          </div>
        </div>
        <div className="flex items-center gap-3">
          <span
            aria-live="polite"
            className={`flex items-center gap-1.5 text-xs font-medium ${
              backend === "ok"
                ? "text-emerald-700"
                : backend === "down"
                  ? "text-rose-700"
                  : "text-slate-500"
            }`}
          >
            <span
              aria-hidden="true"
              className={`size-2 rounded-full ${
                backend === "ok"
                  ? "bg-emerald-500"
                  : backend === "down"
                    ? "bg-rose-500"
                    : "bg-slate-400"
              }`}
            />
            {backend === "ok"
              ? "Backend connected"
              : backend === "down"
                ? "Backend offline"
                : "Checking backend"}
          </span>
          {turns.length > 0 && (
            <button
              className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm font-medium text-slate-700 transition hover:bg-slate-100 disabled:opacity-50"
              disabled={isLoading}
              onClick={startNewChat}
              type="button"
            >
              New chat
            </button>
          )}
        </div>
      </header>

      <main className="flex-1 space-y-4 overflow-y-auto py-6">
        {turns.length === 0 && (
          <div className="mt-16 text-center">
            <h2 className="text-xl font-semibold text-slate-800">
              What would you like to know?
            </h2>
            <p className="mt-2 text-slate-500">
              Answers come from the Snowflake semantic view through Cortex
              Analyst.
            </p>
            <div className="mt-6 flex flex-wrap justify-center gap-2">
              {STARTER_QUESTIONS.map((question) => (
                <button
                  className="rounded-full border border-slate-300 bg-white px-4 py-2 text-sm text-slate-700 transition hover:bg-slate-100"
                  key={question}
                  onClick={() => void submit(question)}
                  type="button"
                >
                  {question}
                </button>
              ))}
            </div>
          </div>
        )}

        {turns.map((turn) =>
          turn.kind === "user" ? (
            <div className="flex justify-end" key={turn.id}>
              <p className="max-w-[85%] whitespace-pre-wrap rounded-2xl rounded-tr-sm bg-slate-900 px-4 py-2.5 text-white">
                {turn.text}
              </p>
            </div>
          ) : turn.kind === "answer" ? (
            <div className="flex justify-start" key={turn.id}>
              <AnswerCard
                answer={turn.answer}
                disabled={isLoading}
                onSuggestion={(question) => void submit(question)}
              />
            </div>
          ) : (
            <div className="flex justify-start" key={turn.id}>
              <p
                className="max-w-[85%] rounded-2xl rounded-tl-sm border border-rose-200 bg-rose-50 px-4 py-2.5 text-sm text-rose-800"
                role="alert"
              >
                {turn.message}
              </p>
            </div>
          ),
        )}

        {isLoading && (
          <p className="animate-pulse text-sm text-slate-500" role="status">
            Asking Cortex Analyst...
          </p>
        )}
        <div ref={endOfChat} />
      </main>

      <form
        className="flex items-end gap-2 border-t border-slate-200 py-4"
        onSubmit={handleSubmit}
      >
        <label className="sr-only" htmlFor="question">
          Your question
        </label>
        <textarea
          className="max-h-40 min-h-12 flex-1 resize-none rounded-xl border border-slate-300 bg-white px-4 py-3 text-slate-900 shadow-sm outline-none transition focus:border-sky-500 focus:ring-2 focus:ring-sky-200"
          id="question"
          maxLength={2000}
          onChange={(event) => setInput(event.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Ask a question, for example: total revenue by region"
          rows={1}
          value={input}
        />
        <button
          className="h-12 rounded-xl bg-sky-600 px-5 font-semibold text-white transition hover:bg-sky-700 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-600 disabled:cursor-not-allowed disabled:opacity-50"
          disabled={isLoading || !input.trim()}
          type="submit"
        >
          Send
        </button>
      </form>
    </div>
  );
}

export default App;
