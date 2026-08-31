// Global fallback ESLint config (flat config).
//
// Applied by the Neovim eslint LSP to TS/JS projects that have NO ESLint config
// of their own. A project's own eslint.config.* always takes precedence — see
// lua/plugins/lazyvim-adjustments/eslint.lua, which only points the LSP at this
// file when the project lacks one.
//
// ESLint Stylistic handles TS/JS *formatting* (the role Prettier plays for
// other filetypes) — chosen because Stylistic preserves authored layout instead
// of reflowing everything the way Prettier does.

import eslint from "@eslint/js";
import tseslint from "typescript-eslint";
import stylistic from "@stylistic/eslint-plugin";
import globals from "globals";

export default tseslint.config(
    // Never lint build output / deps, even as a fallback.
    {
        ignores: [
            "**/node_modules/**",
            "**/dist/**",
            "**/build/**",
            "**/out/**",
            "**/.next/**",
            "**/coverage/**",
        ],
    },

    // C1: base ruleset = recommended + type-checked.
    eslint.configs.recommended,
    ...tseslint.configs.recommendedTypeChecked,

    {
        languageOptions: {
            // projectService mimics the editor's TS server: it auto-resolves each
            // file's tsconfig (so type-checked rules light up wherever a tsconfig
            // exists) and falls back to an inferred project otherwise.
            parserOptions: {
                projectService: true,
            },
            globals: {
                ...globals.node,
                ...globals.browser,
            },
        },

        // C2: individual rule preferences.
        rules: {
            // Unused vars → warn, but allow intentional `_`-prefixed throwaways.
            "@typescript-eslint/no-unused-vars": [
                "warn",
                {
                    argsIgnorePattern: "^_",
                    varsIgnorePattern: "^_",
                    caughtErrorsIgnorePattern: "^_",
                },
            ],
            // Allow `any`, but nudge.
            "@typescript-eslint/no-explicit-any": "warn",
            // Enforce `import type { ... }` for type-only imports.
            "@typescript-eslint/consistent-type-imports": "error",
            // Async safety (needs type info; provided by recommendedTypeChecked).
            "@typescript-eslint/no-floating-promises": "error",
            "@typescript-eslint/await-thenable": "error",
            "@typescript-eslint/no-misused-promises": "error",
            // Prefer `T[]` over `Array<T>`.
            "@typescript-eslint/array-type": ["error", { default: "array" }],
            // Core style / safety.
            "prefer-const": "error",
            eqeqeq: ["error", "smart"],
            // Allow `console` in personal projects (flip to "warn" to nudge).
            "no-console": "off",
        },
    },

    // Formatting via ESLint Stylistic (replaces Prettier for TS/JS).
    //
    // Philosophy: these rules fix specific style violations but DON'T reflow your
    // layout — multiline chains stay multiline, compact objects stay compact,
    // empty braces `{ }` are left alone, and statements aren't force-wrapped.
    // That's the whole reason we use Stylistic here instead of Prettier.
    //
    // Severity is "warn" so formatting nits show yellow (not alarming red); they
    // still auto-fix on save (eslint --fix fixes warn-level rules too).
    {
        plugins: { "@stylistic": stylistic },
        rules: {
            "@stylistic/indent": ["warn", 4, { SwitchCase: 1 }], // B1/B2
            "@stylistic/semi": ["warn", "always"], // B3
            "@stylistic/quotes": [
                "warn",
                "single",
                { avoidEscape: true, allowTemplateLiterals: true },
            ], // B4
            "@stylistic/jsx-quotes": ["warn", "prefer-double"], // B5
            "@stylistic/comma-dangle": ["warn", "always-multiline"], // B6 (= Prettier "all")
            "@stylistic/arrow-parens": ["warn", "as-needed"], // B8 (= Prettier "avoid")
            "@stylistic/object-curly-spacing": ["warn", "always"], // B9
            "@stylistic/quote-props": ["warn", "as-needed"], // B11
            "@stylistic/linebreak-style": ["warn", "unix"], // B12 (lf)
            "@stylistic/member-delimiter-style": "warn", // semicolons in interfaces/types

            // Whitespace normalization — these only adjust HORIZONTAL spacing, so
            // they clean up stray/missing spaces (e.g. `expect(  x  )` → `expect(x)`)
            // without ever reflowing or wrapping lines. This is the bulk of what
            // Prettier's cleanup did, minus the reflowing.
            "@stylistic/space-in-parens": ["warn", "never"],
            "@stylistic/array-bracket-spacing": ["warn", "never"],
            "@stylistic/computed-property-spacing": ["warn", "never"],
            "@stylistic/block-spacing": ["warn", "always"], // `{ foo }` in single-line blocks
            "@stylistic/comma-spacing": ["warn", { before: false, after: true }],
            "@stylistic/semi-spacing": ["warn", { before: false, after: true }],
            "@stylistic/key-spacing": ["warn", { beforeColon: false, afterColon: true }],
            "@stylistic/keyword-spacing": ["warn", { before: true, after: true }],
            "@stylistic/space-before-blocks": ["warn", "always"],
            "@stylistic/space-before-function-paren": [
                "warn",
                { anonymous: "always", named: "never", asyncArrow: "always" },
            ],
            "@stylistic/space-infix-ops": "warn",
            "@stylistic/space-unary-ops": ["warn", { words: true, nonwords: false }],
            "@stylistic/arrow-spacing": ["warn", { before: true, after: true }],
            "@stylistic/function-call-spacing": ["warn", "never"],
            "@stylistic/rest-spread-spacing": ["warn", "never"],
            "@stylistic/template-curly-spacing": ["warn", "never"],
            "@stylistic/no-whitespace-before-property": "warn",
            "@stylistic/no-multi-spaces": "warn",

            // Basic hygiene.
            "@stylistic/eol-last": ["warn", "always"],
            "@stylistic/no-trailing-spaces": "warn",
            "@stylistic/no-multiple-empty-lines": ["warn", { max: 1, maxEOF: 0 }],

            // Optional: force fluent chains onto separate lines. Off by default
            // because it's aggressive (ignoreChainWithDepth: 1 breaks every 2+
            // call chain). Uncomment if you want chains always split.
            // "@stylistic/newline-per-chained-call": ["warn", { ignoreChainWithDepth: 1 }],
        },
    },

    // Plain JS can't be type-checked — disable the type-aware rules there.
    // (Stylistic formatting rules above still apply to JS.)
    {
        files: ["**/*.js", "**/*.cjs", "**/*.mjs", "**/*.jsx"],
        ...tseslint.configs.disableTypeChecked,
    },
);
