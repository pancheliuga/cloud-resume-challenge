import { defineConfig } from "cypress";

export default defineConfig({
  e2e: {
    setupNodeEvents(on, config) {
      // implement node event listeners here
    },
    baseUrl: process.env.WEB_URL,
  },
  env: {
    api: process.env.API_URL,
  },
});