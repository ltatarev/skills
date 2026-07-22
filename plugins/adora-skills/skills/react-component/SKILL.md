---
name: react-component
description: Scaffold a new React or React Native component with sensible defaults. Use when the user asks to create a component, screen, or view in a React or React Native project.
---

Create a new component following these conventions:

- Detect whether the project is React (web) or React Native from package.json and existing imports; match that.
- Use a functional component with hooks. Use TypeScript if the project already uses it.
- One component per file, named in PascalCase, with the filename matching the component.
- Co-locate styles (StyleSheet for React Native, or the project's existing styling approach for web).
- Include a props interface/type and sensible defaults.
- Keep it presentational unless asked otherwise — lift state and data-fetching to the caller.

Before writing, check the project's existing components for the established pattern (styling library, folder structure, export style) and follow it rather than imposing a new one.
