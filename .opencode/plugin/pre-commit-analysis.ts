import type { Plugin } from "@opencode-ai/plugin"

export default (async ({ $ }) => {
  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool !== "bash") return

      const cmd = (input.args?.command ?? "").toString()
      if (!cmd.includes("git commit")) return

      const { stdout, stderr, exitCode } = await $.subprocess("flutter analyze --no-pub", ".")

      const outputText = `${stdout}\n${stderr}`
      const hasIssues =
        exitCode !== 0 ||
        /\berror\b/i.test(outputText) ||
        /\bwarning\b/i.test(outputText)

      if (!hasIssues) return

      const lines = outputText
        .split("\n")
        .map((l: string) => l.trim())
        .filter((l: string) => l.length > 0)

      const relevant = lines.filter(
        (l: string) => /\b(error|warning)\b/i.test(l) && !l.startsWith("Analyzing")
      )

      const summary =
        relevant.length > 0 ? relevant.join("\n") : outputText.slice(0, 1000)

      throw new Error(
        `Commit blocked: analysis has errors/warnings. Fix ALL issues before committing.\n\n${summary}\n\nRule: Run "dart fix --apply" for mechanical fixes, then manually fix remaining issues (print/debugPrint statements, etc.). Re-run "flutter analyze" to verify zero issues, then commit.`
      )
    },
  }
}) satisfies Plugin
