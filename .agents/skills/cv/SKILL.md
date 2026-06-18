---
name: cv
description: Create ATS-friendly, role-targeted resumes for specific job applications. Use when the user invokes /cv, shares a job description, asks for a tailored resume for a company or role, wants recruiter-specific resume variants, or needs resume keyword alignment, bullet prioritization, cover-letter prep, or application-package tuning. Save generated resume source/PDF files under /mnt/media/Documents/Work/CVs/ and append the recruiter name to output filenames when provided.
---

# /cv

Create a targeted resume from the user's existing master materials.

## Goals

Always optimize for:
- ATS-friendly structure and wording
- strong keyword alignment with the target job description
- highest-value experience placed first for the target role
- concrete evidence, tools, systems, and outcomes over generic claims

## Source of truth

Start from the user's existing materials before writing anything new:
- Master resume files stored at the top level of `/mnt/media/Documents/Work/CVs/`
- Portfolio experience entries in `~/workspaces/personal/repos/portfolio/content/experience/`
- Portfolio project entries and related content when relevant
- Resume source files in `~/workspaces/personal/repos/portfolio/resume/` when supporting details are needed
- Any job-specific notes the user provides in chat or files

Prefer the master resume in `/mnt/media/Documents/Work/CVs/` as the primary base. Use the portfolio content to validate, enrich, or retarget it.

Do not invent experience. If a requirement is not supported by evidence, either omit it or ask for clarification.

## Required inputs

Collect or infer these before generating files:
1. target company
2. target role title
3. full job description or link
4. output language (`en`, `fr`, or both)
5. recruiter name if the user wants recruiter-specific filenames

If recruiter name is missing, proceed with a generic filename unless the user explicitly asked for recruiter-specific output in that run.

## Output location and naming

Write all generated files into a company-specific subfolder:
- `/mnt/media/Documents/Work/CVs/{company_name}/`

Create the subfolder if it does not exist.

Use sanitized lowercase tokens with underscores for company, role, and recruiter.

For the `role` token, do **not** use the full pasted job title when it is long. Normalize it to a short, human-readable slug (usually 2--4 words) that captures the core role only.
Examples:
- `senior_developer_infra_data_ai` instead of a much longer pasted title or title+description mashup
- `platform_engineer` instead of `senior_platform_engineer_cloud_infrastructure_kubernetes_observability`

Filename pattern for resumes:
- with recruiter: `YYYY_philippe_lamy_resume_<lang>_<company>_<role>_<recruiter>.tex`
- with recruiter: `YYYY_philippe_lamy_resume_<lang>_<company>_<role>_<recruiter>.pdf`
- without recruiter: `YYYY_philippe_lamy_resume_<lang>_<company>_<role>.tex`
- without recruiter: `YYYY_philippe_lamy_resume_<lang>_<company>_<role>.pdf`

Filename pattern for cover letters:
- `<company>_cover_letter_philippe_lamy.<ext>`

Example:
- `2026_philippe_lamy_resume_en_datadog_platform_engineer_marie_tremblay.pdf`
- `datadog_cover_letter_philippe_lamy.pdf`

## Workflow

1. Read the job description.
2. Extract and list:
   - core responsibilities
   - must-have skills
   - preferred skills
   - keywords likely important for ATS
   - implied seniority and ownership expectations
3. Compare those requirements to the user's proven experience.
4. Pick the most relevant resume base from the existing portfolio resume files.
5. Reorder and rewrite content so the most role-relevant points are emphasized first.
6. Keep section names standard and ATS-friendly:
   - Experience
   - Education
   - Projects
   - Technical Skills
7. Prefer plain, searchable wording over clever phrasing.
8. Mirror the user's strongest evidence for the target role:
   - platform / SRE / DevOps roles: Kubernetes, AWS, EKS, Pulumi, observability, internal platforms, automation, reliability
   - BI / data / analytics roles: dashboards, metrics, monitoring strategy, data pipelines, reporting, stakeholder alignment
   - web / app roles: React, Next.js, TypeScript, delivery, automation, integration work
9. Preserve truthful chronology and titles unless the user explicitly wants a different presentation strategy.
10. Create `/mnt/media/Documents/Work/CVs/{company_name}/` if needed.
11. Generate a tailored cover letter aligned to the same job description and resume positioning.
12. Save the cover letter in that company folder using the filename `{company_name}_cover_letter_philippe_lamy` with the appropriate source/output extension.
13. Build PDFs if the LaTeX toolchain is available.
14. Summarize:
   - why this version matches the job
   - which keywords were emphasized
   - any gaps or follow-up improvements

## Bullet-writing rules

Use bullets that are:
- action-led
- specific about tools or systems when they matter for ATS
- outcome-oriented where evidence exists
- concise enough for a one-page resume when the user wants one page

Prefer this shape:
- `Action verb + what was built/improved + with what + why/result`

Examples:
- `Engineered a reusable multi-account Pulumi bootstrap for AWS EKS, making cluster provisioning consistent across environments and reducing manual setup.`
- `Built reusable automation for service exposure, security, observability, and least-privilege access, making new Kubernetes workloads easier to deploy.`

## ATS rules

Keep the resume ATS-friendly by default:
- use standard headings
- keep dates explicit and consistent
- keep job titles clear
- include exact keywords from the JD when they truthfully match the user's experience
- avoid icons, columns, unusual section labels, and graphics unless the user explicitly wants them
- avoid keyword stuffing; integrate terms naturally into bullets and skills

When working from the existing LaTeX templates, prefer minimal formatting changes unless the user asks for a visual redesign.

## Language handling

If the user asks for both languages:
- produce English and French versions separately
- adapt phrasing idiomatically instead of doing literal word-for-word translation
- keep the same role emphasis across both unless the user asks otherwise

## Optional extras

When useful, also offer or generate:
- a short rationale mapping the resume to the JD
- a recruiter-friendly LinkedIn summary based on the same positioning
- suggested portfolio updates when the JD highlights experience that is underrepresented online

## If the JD is weak or incomplete

If the job description is partial:
- infer likely priorities conservatively
- state assumptions clearly
- ask only the minimum questions needed to produce a high-quality version

## Success criteria

A good `/cv` run should leave the user with:
- a tailored ATS-friendly resume saved in `/mnt/media/Documents/Work/CVs/{company_name}/`
- a tailored cover letter saved in `/mnt/media/Documents/Work/CVs/{company_name}/`
- resume filenames that include the recruiter name when provided
- a cover-letter filename in the form `{company_name}_cover_letter_philippe_lamy`
- the most relevant experience surfaced first
- wording aligned to the target role without exaggeration
