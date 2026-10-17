import Groq from "groq-sdk";
import { GoogleGenerativeAI } from "@google/generative-ai";

// ── Complete Tool Specifications Dictionary ─────────────────────────────────
const allGroqTools = {
  create_task: {
    type: "function",
    function: {
      name: "create_task",
      description: "Creates a new todo task with optional due date and priority",
      parameters: {
        type: "object",
        properties: {
          title: { type: "string", description: "The task title" },
          dueDate: { type: "string", description: "ISO 8601 date string, e.g. 2026-10-18T17:00:00Z" },
          priority: { type: "string", enum: ["low", "medium", "high"], description: "Priority level" }
        },
        required: ["title"]
      }
    }
  },
  create_note: {
    type: "function",
    function: {
      name: "create_note",
      description: "Creates a new journal note",
      parameters: {
        type: "object",
        properties: {
          title: { type: "string", description: "Note headline or title" },
          content: { type: "string", description: "Body content of the note" },
          tags: { type: "array", items: { type: "string" }, description: "Tags for categorization" }
        },
        required: ["title", "content"]
      }
    }
  },
  create_reminder: {
    type: "function",
    function: {
      name: "create_reminder",
      description: "Schedules a reminder alert with date and time",
      parameters: {
        type: "object",
        properties: {
          title: { type: "string", description: "Reminder description" },
          dateTime: { type: "string", description: "ISO 8601 date-time string when alarm should trigger" }
        },
        required: ["title", "dateTime"]
      }
    }
  },
  add_book: {
    type: "function",
    function: {
      name: "add_book",
      description: "Adds a book to the user's Read Tracker reading log. Book cover, author, pages, and synopsis are automatically resolved and fetched via Open Library and Google Books.",
      parameters: {
        type: "object",
        properties: {
          title: { type: "string", description: "Book title" },
          author: { type: "string", description: "Author name" },
          status: {
            type: "string",
            enum: ["toRead", "reading", "read", "onHold", "dropped"],
            description: "Reading progress status (default: toRead)"
          },
          totalPages: { type: "integer", description: "Total page count if known" },
          rating: { type: "number", description: "Rating score from 1.0 to 5.0" },
          notes: { type: "string", description: "Personal notes or review" }
        },
        required: ["title"]
      }
    }
  },
  add_media: {
    type: "function",
    function: {
      name: "add_media",
      description: "Adds a movie, animated film, or anime to the user's Watch Hub. Poster image, release year, genres, synopsis, and episode count are automatically resolved and fetched via TMDB and AniList.",
      parameters: {
        type: "object",
        properties: {
          title: { type: "string", description: "Title of the movie, anime, or series" },
          category: {
            type: "string",
            enum: ["movie", "animatedMovie", "anime"],
            description: "Category of media"
          },
          status: {
            type: "string",
            enum: ["planToWatch", "watching", "completed", "onHold", "dropped"],
            description: "Watch status (default: planToWatch)"
          },
          rating: { type: "number", description: "Rating score from 1.0 to 10.0" },
          notes: { type: "string", description: "Review or thoughts" }
        },
        required: ["title"]
      }
    }
  },
  create_learning_path: {
    type: "function",
    function: {
      name: "create_learning_path",
      description: "Creates a structured learning roadmap or skill path with milestone steps",
      parameters: {
        type: "object",
        properties: {
          title: { type: "string", description: "Title of the learning roadmap or skill path" },
          description: { type: "string", description: "Detailed description of the goal" },
          steps: {
            type: "array",
            items: { type: "string" },
            description: "Sequential list of milestone step titles to complete"
          }
        },
        required: ["title"]
      }
    }
  }
};

const allGeminiDeclarations = {
  create_task: {
    name: "create_task",
    description: "Creates a new todo task with optional due date and priority",
    parameters: {
      type: "OBJECT",
      properties: {
        title: { type: "STRING", description: "The task title" },
        dueDate: { type: "STRING", description: "ISO 8601 date string, e.g. 2026-10-18T17:00:00Z" },
        priority: { type: "STRING", enum: ["low", "medium", "high"] }
      },
      required: ["title"]
    }
  },
  create_note: {
    name: "create_note",
    description: "Creates a new journal note",
    parameters: {
      type: "OBJECT",
      properties: {
        title: { type: "STRING", description: "Note headline or title" },
        content: { type: "STRING", description: "Body content of the note" },
        tags: { type: "ARRAY", items: { type: "STRING" } }
      },
      required: ["title", "content"]
    }
  },
  create_reminder: {
    name: "create_reminder",
    description: "Schedules a reminder alert with date and time",
    parameters: {
      type: "OBJECT",
      properties: {
        title: { type: "STRING", description: "Reminder description" },
        dateTime: { type: "STRING", description: "ISO 8601 date-time string when alarm should trigger" }
      },
      required: ["title", "dateTime"]
    }
  },
  add_book: {
    name: "add_book",
    description: "Adds a book to the user's Read Tracker reading log. Book cover, author, pages, and synopsis are automatically fetched via Open Library.",
    parameters: {
      type: "OBJECT",
      properties: {
        title: { type: "STRING", description: "Book title" },
        author: { type: "STRING", description: "Author name" },
        status: {
          type: "STRING",
          enum: ["toRead", "reading", "read", "onHold", "dropped"],
          description: "Reading progress status"
        },
        totalPages: { type: "INTEGER", description: "Total page count" },
        rating: { type: "NUMBER", description: "Rating score from 1.0 to 5.0" },
        notes: { type: "STRING", description: "Personal notes or review" }
      },
      required: ["title"]
    }
  },
  add_media: {
    name: "add_media",
    description: "Adds a movie, animated film, or anime to the user's Watch Hub. Poster, year, genres, and synopsis are automatically fetched via TMDB and AniList.",
    parameters: {
      type: "OBJECT",
      properties: {
        title: { type: "STRING", description: "Title of the movie, anime, or series" },
        category: {
          type: "STRING",
          enum: ["movie", "animatedMovie", "anime"],
          description: "Category of media"
        },
        status: {
          type: "STRING",
          enum: ["planToWatch", "watching", "completed", "onHold", "dropped"],
          description: "Watch status"
        },
        rating: { type: "NUMBER", description: "Rating score from 1.0 to 10.0" },
        notes: { type: "STRING", description: "Review or thoughts" }
      },
      required: ["title"]
    }
  },
  create_learning_path: {
    name: "create_learning_path",
    description: "Creates a structured learning roadmap or skill path with milestone steps",
    parameters: {
      type: "OBJECT",
      properties: {
        title: { type: "STRING", description: "Title of the learning roadmap or skill path" },
        description: { type: "STRING", description: "Detailed description of the goal" },
        steps: {
          type: "ARRAY",
          items: { type: "STRING" },
          description: "Sequential list of milestone step titles to complete"
        }
      },
      required: ["title"]
    }
  }
};

function getFilteredGroqTools(enabledFeatures = ["notes", "tasks", "reminders"]) {
  const tools = [];
  if (enabledFeatures.includes("tasks")) tools.push(allGroqTools.create_task);
  if (enabledFeatures.includes("notes")) tools.push(allGroqTools.create_note);
  if (enabledFeatures.includes("reminders")) tools.push(allGroqTools.create_reminder);
  if (enabledFeatures.includes("read")) tools.push(allGroqTools.add_book);
  if (enabledFeatures.includes("watch")) tools.push(allGroqTools.add_media);
  if (enabledFeatures.includes("learning_paths")) tools.push(allGroqTools.create_learning_path);
  return tools;
}

function getFilteredGeminiDeclarations(enabledFeatures = ["notes", "tasks", "reminders"]) {
  const declarations = [];
  if (enabledFeatures.includes("tasks")) declarations.push(allGeminiDeclarations.create_task);
  if (enabledFeatures.includes("notes")) declarations.push(allGeminiDeclarations.create_note);
  if (enabledFeatures.includes("reminders")) declarations.push(allGeminiDeclarations.create_reminder);
  if (enabledFeatures.includes("read")) declarations.push(allGeminiDeclarations.add_book);
  if (enabledFeatures.includes("watch")) declarations.push(allGeminiDeclarations.add_media);
  if (enabledFeatures.includes("learning_paths")) declarations.push(allGeminiDeclarations.create_learning_path);
  return declarations;
}

function buildSystemPrompt(workspaceId, enabledFeatures) {
  return `You are LogsPad AI, an intelligent personal productivity assistant built into the LogsPad app.
Current date and time: ${new Date().toISOString()}.
Active workspace: "${workspaceId || "Personal"}".
Enabled modules in this workspace: [${(enabledFeatures || ["notes", "tasks", "reminders"]).join(", ")}].

Operational Rules:
- When the user asks you to write, save, track, remind, or create an item, ALWAYS invoke the corresponding tool.
- You have tools ONLY for the modules enabled in this workspace.
- If the user asks to use a feature that is NOT enabled in their workspace (for example, adding a book when "read" is not enabled, or adding media when "watch" is not enabled), politely inform them that this feature is currently not installed in this workspace, and can be installed via the Feature Marketplace in the sidebar.
- Keep conversational replies helpful, friendly, and concise.`;
}

// ── Handler for Groq (Qwen 2.5 / 3.8) ─────────────────────────────────────────
async function executeGroq({ messages, workspaceId, enabledFeatures, model }) {
  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) throw new Error("GROQ_API_KEY environment variable is not configured.");

  const groq = new Groq({ apiKey });
  const activeFeatures = enabledFeatures || ["notes", "tasks", "reminders"];
  const tools = getFilteredGroqTools(activeFeatures);

  const systemPrompt = buildSystemPrompt(workspaceId, activeFeatures);

  const chatMessages = [
    { role: "system", content: systemPrompt },
    ...(messages || [])
  ];

  const completionParams = {
    model: model || "qwen/qwen3.8-27b",
    messages: chatMessages,
    temperature: 0.3
  };

  if (tools.length > 0) {
    completionParams.tools = tools;
    completionParams.tool_choice = "auto";
  }

  const completion = await groq.chat.completions.create(completionParams);

  const choice = completion.choices[0].message;
  const actions = [];

  if (choice.tool_calls && choice.tool_calls.length > 0) {
    for (const call of choice.tool_calls) {
      actions.push({
        type: call.function.name,
        data: JSON.parse(call.function.arguments)
      });
    }
  }

  return {
    reply: choice.content || "I have processed your request.",
    actions,
    engine: `Groq (${model || "qwen/qwen3.8-27b"})`
  };
}

// ── Handler for Google Gemini ───────────────────────────────────────────────
async function executeGemini({ messages, workspaceId, enabledFeatures, model }) {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) throw new Error("GEMINI_API_KEY environment variable is not configured.");

  const genAI = new GoogleGenerativeAI(apiKey);
  const activeFeatures = enabledFeatures || ["notes", "tasks", "reminders"];
  const declarations = getFilteredGeminiDeclarations(activeFeatures);

  const modelConfig = {
    model: model || "gemini-flash-latest",
    systemInstruction: buildSystemPrompt(workspaceId, activeFeatures)
  };

  if (declarations.length > 0) {
    modelConfig.tools = [{ functionDeclarations: declarations }];
  }

  const geminiModel = genAI.getGenerativeModel(modelConfig);

  // Convert conversation format to Gemini contents
  const contents = (messages || []).map((m) => ({
    role: m.role === "assistant" ? "model" : "user",
    parts: [{ text: m.content }]
  }));

  const chat = geminiModel.startChat({
    history: contents.slice(0, -1)
  });

  const lastUserMessage = contents[contents.length - 1]?.parts[0]?.text || "Hello";
  const result = await chat.sendMessage(lastUserMessage);
  const response = result.response;

  const actions = [];
  const functionCalls = response.functionCalls();
  if (functionCalls && functionCalls.length > 0) {
    for (const call of functionCalls) {
      actions.push({
        type: call.name,
        data: call.args
      });
    }
  }

  return {
    reply: response.text() || "I have processed your request.",
    actions,
    engine: `Gemini (${model || "gemini-flash-latest"})`
  };
}

// ── Vercel Serverless Function Entry Point ──────────────────────────────────
export default async function handler(req, res) {
  // CORS configuration
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") {
    return res.status(200).end();
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed. Use POST." });
  }

  const { messages, workspaceId, enabledFeatures, provider, model } = req.body || {};
  const selectedProvider = (provider || process.env.DEFAULT_PROVIDER || "groq").toLowerCase();

  try {
    let result;

    if (selectedProvider === "gemini") {
      try {
        result = await executeGemini({ messages, workspaceId, enabledFeatures, model });
      } catch (geminiErr) {
        if (process.env.GROQ_API_KEY) {
          console.warn("Gemini execution failed, falling back to Groq:", geminiErr.message);
          result = await executeGroq({ messages, workspaceId, enabledFeatures, model });
        } else {
          throw geminiErr;
        }
      }
    } else {
      // Default to Groq (Qwen)
      try {
        result = await executeGroq({ messages, workspaceId, enabledFeatures, model });
      } catch (groqErr) {
        if (process.env.GEMINI_API_KEY) {
          console.warn("Groq execution failed, falling back to Gemini:", groqErr.message);
          result = await executeGemini({ messages, workspaceId, enabledFeatures, model });
        } else {
          throw groqErr;
        }
      }
    }

    return res.status(200).json(result);
  } catch (error) {
    console.error("AI Agent Backend Error:", error);
    return res.status(500).json({
      error: error.message || "Internal server error during agent execution."
    });
  }
}
