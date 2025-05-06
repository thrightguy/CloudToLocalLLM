module.exports = {
  root: true,
  env: {
    node: true,
    browser: true,
    es2021: true
  },
  extends: [
    'plugin:vue/vue3-recommended',
    'eslint:recommended'
  ],
  parserOptions: {
    ecmaVersion: 2021,
    sourceType: 'module'
  },
  rules: {
    'no-console': process.env.NODE_ENV === 'production' ? 'warn' : 'off',
    'no-debugger': process.env.NODE_ENV === 'production' ? 'warn' : 'off',
    'vue/component-name-in-template-casing': ['error', 'PascalCase'],
    'vue/html-closing-bracket-newline': ['error', {
      'singleline': 'never',
      'multiline': 'always'
    }],
    'vue/html-self-closing': ['error', {
      'html': {
        'void': 'always',
        'normal': 'always',
        'component': 'always'
      }
    }],
    'vue/max-attributes-per-line': ['error', {
      'singleline': 1,
      'multiline': 1
    }],
    'vue/multi-word-component-names': ['error', {
      'ignores': []
    }],
    'vue/no-v-html': 'error',
    'vue/require-default-prop': 'error',
    'vue/require-explicit-emits': 'error',
    'semi': ['error', 'always'],
    'quotes': ['error', 'single'],
    'comma-dangle': ['error', 'never']
  }
} 