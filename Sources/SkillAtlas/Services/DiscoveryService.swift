import Foundation

actor DiscoveryService {
    private let knownSkills: [(name: String, description: String, source: String, url: String)] = [
        ("playwright", "Browser automation with Playwright", "GitHub (openai/skills)", "https://github.com/openai/skills"),
        ("playwright-interactive", "Interactive Playwright debugging REPL", "GitHub (openai/skills)", "https://github.com/openai/skills"),
        ("doc", "DOCX reading, creation & editing", "GitHub (anthropics/skills)", "https://github.com/anthropics/skills"),
        ("pdf", "PDF reading, generation & review", "GitHub (anthropics/skills)", "https://github.com/anthropics/skills"),
        ("pptx-analysis", "PPTX analysis & modification", "GitHub (vercel-labs/skills)", "https://github.com/vercel-labs/skills"),
        ("qwen-ocr", "OCR & table extraction using Qwen", "GitHub (openai/skills)", "https://github.com/openai/skills"),
        ("screenshot", "System screenshot capture tool", "GitHub (anthropics/skills)", "https://github.com/anthropics/skills"),
        ("vercel-deploy", "Deploy websites to Vercel", "GitHub (vercel-labs/skills)", "https://github.com/vercel-labs/skills"),
        ("render-deploy", "Deploy apps to Render", "GitHub (openai/skills)", "https://github.com/openai/skills"),
        ("tokscale-token-report", "Local AI token usage & cost statistics", "GitHub (openai/skills)", "https://github.com/openai/skills"),
        ("hit-thesis-format", "HIT thesis formatting", "GitHub (anthropics/skills)", "https://github.com/anthropics/skills"),
        ("repo-auto-ship", "Automated release pipeline", "GitHub (vercel-labs/skills)", "https://github.com/vercel-labs/skills"),
        ("pdf-page-screenshots", "Export PDF pages as PNG screenshots", "GitHub (openai/skills)", "https://github.com/openai/skills"),
        ("agent-monopoly-minimal-ui", "Agent Monopoly minimal linear UI", "GitHub (openai/skills)", "https://github.com/openai/skills"),
        ("agent-monopoly-poster-ui", "Agent Monopoly poster map UI", "GitHub (openai/skills)", "https://github.com/openai/skills"),
        ("nev-broker-report-pro", "Deep equity research report generator", "GitHub (anthropics/skills)", "https://github.com/anthropics/skills"),
        ("codex-system-imagegen", "Generate & edit bitmap images", "System", "system"),
        ("codex-system-skill-creator", "Create new skills", "System", "system"),
        ("codex-system-skill-installer", "Install curated skills", "System", "system"),
        ("codex-system-plugin-creator", "Create Codex plugins", "System", "system"),
        ("codex-system-openai-docs", "OpenAI API documentation", "System", "system"),
    ]

    func discover(query: String, installedSkills: [SkillRecord]) -> [DiscoverResult] {
        let lowerQuery = query.lowercased()
        let queryTerms = lowerQuery.split(separator: " ").map(String.init)

        // If query is empty or too short, return some suggestions
        guard !queryTerms.isEmpty, query.count >= 2 else {
            return installedSkills.map { skill in
                let side = skill.codexExists && skill.claudeExists ? "both"
                    : skill.codexExists ? "codex" : "claude"
                return DiscoverResult(
                    name: skill.name,
                    description: skill.description ?? "No description",
                    source: "Local",
                    url: skill.codexPath ?? skill.claudePath ?? "",
                    updatedAt: "",
                    isInstalled: true,
                    installedSide: side
                )
            }
        }

        // Score known skills by relevance
        var scored: [(result: DiscoverResult, score: Int)] = []

        for known in knownSkills {
            let searchableText = "\(known.name) \(known.description)".lowercased()
            let score = queryTerms.reduce(0) { total, term in
                total + (searchableText.contains(term) ? 1 : 0)
            }
            if score > 0 {
                let isInstalled = installedSkills.contains(where: { $0.name == known.name })
                let installedSide: String? = {
                    guard isInstalled else { return nil }
                    if let s = installedSkills.first(where: { $0.name == known.name }) {
                        return s.codexExists && s.claudeExists ? "both"
                            : s.codexExists ? "codex" : "claude"
                    }
                    return nil
                }()
                scored.append((
                    DiscoverResult(
                        name: known.name,
                        description: known.description,
                        source: known.source,
                        url: known.url,
                        updatedAt: "Recent",
                        isInstalled: isInstalled,
                        installedSide: installedSide
                    ),
                    score
                ))
            }
        }

        // Also search installed skills that might not be in known list
        for skill in installedSkills {
            let searchableText = "\(skill.name) \(skill.description ?? "")".lowercased()
            let score = queryTerms.reduce(0) { total, term in
                total + (searchableText.contains(term) ? 1 : 0)
            }
            let alreadyAdded = scored.contains(where: { $0.result.name == skill.name })
            if score > 0 && !alreadyAdded {
                let side = skill.codexExists && skill.claudeExists ? "both"
                    : skill.codexExists ? "codex" : "claude"
                scored.append((
                    DiscoverResult(
                        name: skill.name,
                        description: skill.description ?? "No description",
                        source: "Local",
                        url: skill.codexPath ?? skill.claudePath ?? "",
                        updatedAt: "",
                        isInstalled: true,
                        installedSide: side
                    ),
                    score
                ))
            }
        }

        // Sort by score descending, then installed status
        scored.sort { a, b in
            if a.score != b.score { return a.score > b.score }
            if a.result.isInstalled != b.result.isInstalled { return a.result.isInstalled }
            return a.result.name < b.result.name
        }

        return scored.map { $0.result }
    }
}
