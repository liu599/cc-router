// ~/.claude-code-router/transformers/gemini-reasoning.js

class GeminiReasoningTransformer {
  constructor(config) {
    this.config = config;
  }

  /**
   * Transforms the incoming request from Claude Code to the Gemini API format.
   * Handles "thinking" parameters for reasoning models.
   */
  async transformRequest(request) {
    const model = request.model || "gemini-2.0-flash-thinking-exp-01-21";
    
    // 1. Map Messages to Gemini "Contents"
    let systemInstruction = undefined;
    const contents = [];

    for (const msg of request.messages) {
      if (msg.role === 'system') {
        // Gemini handles system prompts via a specific field, not as a message in contents
        systemInstruction = {
          parts: [{ text: msg.content }]
        };
      } else {
        const parts = [];
        if (typeof msg.content === 'string') {
          parts.push({ text: msg.content });
        } else if (Array.isArray(msg.content)) {
          // Handle multimodal content (images, etc.) if present
          for (const item of msg.content) {
            if (item.type === 'text') {
              parts.push({ text: item.text });
            } else if (item.type === 'image_url') {
              // Basic handling for image URLs - assumes base64 or public URL
              // For full robustness, you might need to fetch and convert to inlineData
              parts.push({ text: "[Image input not fully supported in this snippet]" }); 
            }
          }
        }
        
        // Map 'assistant' to 'model' for Gemini
        const role = msg.role === 'assistant' ? 'model' : 'user';
        contents.push({ role, parts });
      }
    }

    // 2. Construct the Gemini API Payload
    const payload = {
      contents,
      systemInstruction,
      generationConfig: {
        // Crucial for reasoning models:
        includeThoughts: true, 
        maxOutputTokens: request.max_tokens || 8192,
        temperature: request.temperature ?? 0.7, // Thinking models often prefer non-zero temp
      }
    };

    // 3. Return the transformed request
    return {
      url: `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${this.config.apiKey}`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    };
  }

  /**
   * Transforms the response from Gemini back to the OpenAI-compatible format Claude Code expects.
   * Extracts "thoughts" and wraps them in <think> tags.
   */
  async transformResponse(response) {
    const data = await response.json();

    if (data.error) {
      throw new Error(`Gemini API Error: ${data.error.message}`);
    }

    const candidate = data.candidates?.[0];
    if (!candidate) return { choices: [] };

    let fullContent = "";
    let reasoningContent = "";

    // Iterate through parts to separate thoughts from actual content
    if (candidate.content && candidate.content.parts) {
      for (const part of candidate.content.parts) {
        // Check for the "thought" property (specific to Gemini thinking models)
        if (part.thought === true) {
          reasoningContent += part.text + "\n";
        } else {
          fullContent += part.text;
        }
      }
    }

    // If we found reasoning, prepend it in <think> tags like DeepSeek R1
    // This allows the router/client to potentially display it specially
    if (reasoningContent) {
      fullContent = `<think>\n${reasoningContent.trim()}\n</think>\n\n${fullContent}`;
    }

    // Return in the OpenAI chat completion format
    return {
      id: `chatcmpl-${Date.now()}`,
      object: 'chat.completion',
      created: Math.floor(Date.now() / 1000),
      model: 'gemini-reasoning',
      choices: [
        {
          index: 0,
          message: {
            role: 'assistant',
            content: fullContent,
          },
          finish_reason: candidate.finishReason === 'STOP' ? 'stop' : 'length',
        },
      ],
      usage: {
        // Basic approximation if usage metadata isn't perfect
        prompt_tokens: data.usageMetadata?.promptTokenCount || 0,
        completion_tokens: data.usageMetadata?.candidatesTokenCount || 0,
        total_tokens: data.usageMetadata?.totalTokenCount || 0
      }
    };
  }
}

module.exports = GeminiReasoningTransformer;