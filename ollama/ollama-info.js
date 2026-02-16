#!/usr/bin/env node
const puppeteer = require("puppeteer");
const readline = require("readline");

const MODELS = ["llama4", "mistral", "qwen2.5"]; // Add other base models here

async function chooseModel() {
  return new Promise((resolve) => {
    console.log("Select a model:");
    MODELS.forEach((m, i) => console.log(`${i + 1}. ${m}`));

    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });

    rl.question("Enter number: ", (num) => {
      rl.close();
      const idx = parseInt(num) - 1;
      if (idx >= 0 && idx < MODELS.length) {
        resolve(MODELS[idx]);
      } else {
        console.error("Invalid selection");
        process.exit(1);
      }
    });
  });
}

(async () => {
  const model = await chooseModel();
  const url = `https://ollama.com/library/${model}`;

  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();
  await page.goto(url, { waitUntil: "networkidle2" });

  const info = await page.evaluate(() => {
    const name = document.querySelector("h1")?.textContent.trim() || "";
    const desc = document.querySelector("p")?.textContent.trim() || "";
    const sizes = Array.from(
      document.querySelectorAll(".text-sm, .model-size, span")
    )
      .map((el) => el.textContent.trim())
      .filter((t) => t.match(/[0-9]+[bB]|[0-9]+x[0-9]+[bB]/)); // basic size pattern
    return { name, desc, sizes };
  });

  console.log("\n--- Model Info ---");
  console.log("Name       :", info.name);
  console.log("Description:", info.desc);
  console.log("Sizes      :", info.sizes.join(", "));

  await browser.close();
})();
