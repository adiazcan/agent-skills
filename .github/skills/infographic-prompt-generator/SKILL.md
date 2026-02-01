---
name: infographic-prompt-generator
description: Generates optimized prompts for image generation models (such as Nano Banana, DALL-E, Midjourney, Stable Diffusion) that create visual infographics from textual content. Use this skill when you need to convert information, data, concepts, or explanations into detailed prompts for creating visually attractive infographics. Triggers: "create infographic", "generate infographic prompt", "convert to visual", "make infographic of", "prompt for informative image", "visualize this content".
---

# Infographic Prompt Generator

Generates structured prompts for image models to create professional infographics based on textual content.

## Workflow

1. **Receive content**: Analyze the content provided by the user
2. **Load base style**: Read [references/styles.md](references/styles.md) to get the configured style and theme
3. **Structure information**: Identify key elements, data, visual hierarchy
4. **Generate prompt**: Create the optimized prompt for the image model
5. **Create markdown file**: **ALWAYS** save the generated prompt to a markdown file

## Content Analysis

Extract from the provided content:
- **Content language**: Detect the language to preserve it in the infographic texts
- **Main title**: Central concept or theme
- **Key points**: 3-7 main elements to visualize
- **Numerical data**: Statistics, percentages, relevant figures
- **Relationships**: Connections, flows, comparisons between elements
- **Hierarchy**: Order of importance of information

**IMPORTANT about languages**:
- The prompt must always be in **English** (image models work better with English prompts)
- The texts that will appear IN the infographic (titles, labels, descriptions) must remain in the **original language** of the provided content
- Include literal texts in quotes within the English prompt

## Generated Prompt Structure

**ALWAYS create a markdown file** with the generated prompt using the following format:

```markdown
# Infographic Prompt: [Title]

## Main Prompt

[Complete optimized prompt for the image model]

## Suggested Visual Elements

- [List of relevant icons/symbols]
- [Suggested color palette]
- [Recommended typography]
```

**File naming**: The markdown file name must be derived from the main title of the provided content. Convert the title to lowercase, replace spaces with hyphens, remove special characters, and prepend any numbers from the title at the beginning (e.g., content titled "5 técnicas para mejorar la productividad" → `5-tecnicas-para-mejorar-la-productividad.md`).

## Prompt Composition

### Base Structure

```
[Image type] + [Visual style] + [Main content] + [Specific elements] + [Color palette] + [Composition] + [Technical quality]
```

### Prompt Components

1. **Image type**: "infographic", "visual guide", "data visualization", "educational poster"
2. **Visual style**: Extracted from [references/styles.md](references/styles.md)
3. **Main content**: Title and central concept of the content
4. **Specific elements**: Icons, graphics, sections based on key points
5. **Color palette**: According to base style or content theme
6. **Composition**: "vertical layout", "sections", "flowchart style", "modular design"
7. **Technical quality**: "high resolution", "clean design", "professional", "print-ready"

### Effective Keywords

- **For clarity**: clean, organized, structured, readable, clear hierarchy
- **For professionalism**: professional, modern, corporate, polished
- **For engagement**: vibrant, eye-catching, dynamic, engaging
- **For data**: data-driven, statistical, metrics, charts, graphs
- **For education**: educational, informative, explanatory, step-by-step

## Transformation Examples

### Example 1: Spanish Content

**Original content:**
> "5 técnicas para mejorar la productividad: 1) Técnica Pomodoro, 2) Matriz de Eisenhower, 3) Time blocking, 4) Regla de los 2 minutos, 5) Revisión semanal"

**Generated prompt:**
> "Professional vertical infographic, modern flat design style, title text '5 técnicas para mejorar la productividad', 5 numbered sections with icons and Spanish labels: '1. Técnica Pomodoro' with tomato timer icon, '2. Matriz de Eisenhower' with 2x2 grid icon, '3. Time blocking' with calendar blocks icon, '4. Regla de los 2 minutos' with stopwatch icon, '5. Revisión semanal' with checklist icon, vibrant blue and orange color palette, clean white background, clear hierarchy, high resolution, vector illustration style"

### Example 2: Spanish Content with Data

**Original content:**
> "El 70% de los empleados trabajan mejor con horarios flexibles. El 45% prefiere trabajo híbrido. Solo el 15% quiere volver 100% presencial."

**Generated prompt:**
> "Data-driven infographic about workplace preferences, minimalist corporate style, three main statistics displayed as percentage circles: '70% Horarios flexibles', '45% Trabajo híbrido', '15% 100% presencial', icons representing each work mode, professional blue and gray color scheme with accent green, clean typography with Spanish text labels, organized vertical layout with clear data hierarchy, modern business illustration style, high quality print-ready design"

## Customization

To modify the base style for infographics, edit the [references/styles.md](references/styles.md) file with:
- Preferred visual style
- Corporate color palette
- Theme or industry
- Composition preferences
