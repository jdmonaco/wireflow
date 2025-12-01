# Context & Input

Understand the distinction between input and context files, supported document types, and how content is aggregated.

## Input vs Context

WireFlow distinguishes between **input** (primary documents to process) and **context** (supporting materials):

| Aspect | Input (`-in`) | Context (`-cx`) |
|--------|---------------|-----------------|
| **Purpose** | Documents to analyze/transform | Background information |
| **Position** | After context in prompt | Before input in prompt |
| **Typical use** | PDFs to summarize, data to analyze | Reference docs, prior outputs |
| **Citations** | Yes (with `--enable-citations`) | Yes |

**Example:**

```bash
# Summarize a report (input) using style guide (context)
wfw run summarize -in report.pdf -cx style-guide.md

# Analyze data (input) with reference materials (context)
wfw run analyze -in results.csv -cx methodology.md prior-analysis.md
```

## Supported Document Types

### Text Files

All text-based files (`.md`, `.txt`, `.py`, `.js`, `.csv`, etc.) are processed directly with syntax highlighting based on extension.

```bash
wfw run analysis -cx data.csv script.py notes.md
```

### PDF Documents

- Processed using Claude API (text + visual analysis)
- Maximum size: 32MB per PDF
- Supports citations with document indices

```bash
wfw run analysis -in report.pdf -cx references.pdf
```

### Microsoft Office Files

- **Supported:** `.docx`, `.pptx`
- Auto-converted to PDF via LibreOffice
- Cached in `.workflow/cache/office/`
- Citations use original filename

```bash
wfw run summary -in presentation.pptx -cx notes.docx
```

**Requirements:** LibreOffice installed (`libreoffice` or `soffice` in PATH)

### Images

- **Native:** `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`
- **Converted:** `.heic` → JPEG, `.tiff` → PNG, `.svg` → PNG
- Processed using Claude Vision API
- Auto-resize if larger than 1568px on longest edge
- Maximum size: 5MB per image
- NOT citable (no document indices)

```bash
wfw run analyze-diagram -in flowchart.svg -cx photo.heic
```

**Requirements:**

- HEIC: `sips` (macOS) or ImageMagick
- TIFF: `sips` (macOS) or ImageMagick
- SVG: `rsvg-convert` (librsvg) or Inkscape

### Mixing Types

```bash
wfw run research \
    -in "papers/*.pdf" \
    -cx notes.docx \
    -cx diagram.png \
    -cx references.md
```

## Context Aggregation

Content is assembled in this order:

**Run mode:**

1. System prompts (`SYSTEM_PROMPTS`)
2. Project description (`project.txt`)
3. Context files (config + CLI)
4. Dependencies (`--depends-on` outputs)
5. Input files (config + CLI)
6. Images
7. Task prompt (`task.txt`)

**Task mode:**

1. System prompts
2. Project description (if in project)
3. Context files (CLI)
4. Input files (CLI)
5. Images
6. Task prompt (inline or template)

## Path Specification

Both config files and CLI options accept flexible path specifications for INPUT and CONTEXT. All path types work consistently across both methods.

### Supported Path Types

| Path Type | Config File | CLI Option | Example |
|-----------|-------------|------------|---------|
| Relative file | Project-root relative | CWD-relative | `data/notes.md` |
| Absolute file | Direct resolution | Direct resolution | `/tmp/shared/ref.pdf` |
| Relative directory | Project-root relative | CWD-relative | `data/` |
| Absolute directory | Direct resolution | Direct resolution | `/external/docs/` |
| Glob pattern | Expands from project root | Shell-expands from CWD | `data/*.csv` |

### Config File Paths

Paths in config files support relative paths (resolved from project root), absolute paths (anywhere on filesystem), and directories (expanded non-recursively):

```bash
# In .workflow/config or .workflow/run/<name>/config

# Relative paths (project-root relative)
CONTEXT=(notes/analysis.md refs/paper.pdf)

# Absolute paths (external files)
CONTEXT=(/tmp/shared-docs/reference.pdf /home/user/data/notes.md)

# Directories (expanded to supported files, non-recursive)
CONTEXT=(docs/ /external/shared-resources/)

# Glob patterns (expand at config source time from project root)
CONTEXT=(data/*.csv notes/**/*.md)

# Mixed paths
CONTEXT=(
    notes/local.md              # Relative file
    /tmp/external.pdf           # Absolute file
    data/                       # Relative directory
    /shared/docs/               # Absolute directory
    "reports/*.pdf"             # Glob pattern
)

INPUT=(main-report.pdf /external/data.csv)
```

### CLI Paths

CLI paths are resolved relative to your current working directory:

```bash
cd /project/subdir
wfw run analysis -cx local-notes.md
# Looks for: /project/subdir/local-notes.md

# Relative to CWD
wfw run analysis -cx data.csv -in report.pdf

# Absolute paths
wfw run analysis -cx /tmp/external-notes.md

# Directories (expanded non-recursively)
wfw run analysis -cx docs/ -in /external/data/

# Glob patterns (shell-expands before passing to WireFlow)
wfw run analysis -cx "data/*.csv" -in "reports/*.pdf"
```

### Glob Patterns

```bash
# Single directory pattern
-cx "data/*.csv"

# Recursive pattern
-cx "notes/**/*.md"

# Multiple directories with brace expansion
-cx "data/{exp1,exp2}/*"

# In config (globs expand at source time from project root)
CONTEXT=(data/*.csv notes/**/*.md)
INPUT=(reports/**/*.pdf)
```

### Directory Expansion

When a directory path is specified:

- Expansion is **non-recursive** (only immediate children)
- Only **supported file types** are included (text, PDF, Office, images)
- Binary files (executables, archives, etc.) are automatically excluded

```bash
# Directory with mixed content
data/
├── results.csv      # ✓ Included (text)
├── chart.png        # ✓ Included (image)
├── report.pdf       # ✓ Included (PDF)
├── archive.zip      # ✗ Excluded (binary)
└── subdir/          # ✗ Not traversed (non-recursive)
    └── more.txt     # ✗ Excluded (in subdirectory)
```

## Caching

WireFlow caches converted files to speed up repeated runs.

### Office Conversion Cache

Location: `.workflow/cache/office/`

- PDF conversions are cached per source file
- Cache invalidated when source file changes (by mtime)
- Shared across all workflows in the project

### Image Conversion Cache

Location: `.workflow/cache/images/`

- Resized/converted images cached per source
- HEIC→JPEG, TIFF→PNG, SVG→PNG conversions cached
- Original dimensions preserved in cache filename

### Cache Management

```bash
# Clear project cache
rm -rf .workflow/cache/

# View cache contents
ls -la .workflow/cache/office/
ls -la .workflow/cache/images/
```

## Configuration Variables

| Variable | Description | Scope |
|----------|-------------|-------|
| `CONTEXT` | Context file paths (globs expand at source time) | Project, Workflow |
| `INPUT` | Input file paths (globs expand at source time) | Workflow |
| `ENABLE_CITATIONS` | Enable source citations | All |

## Best Practices

**Input vs Context:**

- Use `-in` for documents you're actively processing
- Use `-cx` for reference materials, prior outputs, style guides
- Dependencies (`--depends-on`) automatically become context

**File organization:**

- Keep source documents in predictable locations
- Use glob patterns for dynamic file sets: `CONTEXT=(data/*.csv)`
- Use explicit paths for fixed sets: `INPUT=(report.pdf summary.md)`

**Performance:**

- First run with Office/image files is slower (conversion)
- Subsequent runs use cache
- Large images auto-resize to reduce API costs

---

Continue to [Execution Modes](execution.md) →
