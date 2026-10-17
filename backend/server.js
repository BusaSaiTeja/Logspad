import http from "node:http";
import handler from "./api/chat.js";

const PORT = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  // Polyfill Express-like helpers for the serverless handler
  res.status = (code) => {
    res.statusCode = code;
    return res;
  };

  res.json = (data) => {
    res.setHeader("Content-Type", "application/json");
    res.end(JSON.stringify(data));
    return res;
  };

  if (req.method === "OPTIONS") {
    return handler(req, res);
  }

  if (req.url === "/api/chat" || req.url === "/") {
    let body = "";
    req.on("data", (chunk) => {
      body += chunk;
    });

    req.on("end", () => {
      try {
        req.body = body ? JSON.parse(body) : {};
      } catch {
        req.body = {};
      }
      handler(req, res);
    });
  } else {
    res.writeHead(404, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "Not found" }));
  }
});

server.listen(PORT, () => {
  console.log(`🚀 MyLogs Dual-Engine AI Agent backend running on http://localhost:${PORT}/api/chat`);
  console.log(`- Groq API Key: ${process.env.GROQ_API_KEY ? "Configured ✅" : "Missing ❌"}`);
  console.log(`- Gemini API Key: ${process.env.GEMINI_API_KEY ? "Configured ✅" : "Missing ❌"}`);
});
