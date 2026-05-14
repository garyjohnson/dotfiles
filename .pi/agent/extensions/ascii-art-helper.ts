/**
 * ASCII Art Helper Extension
 * 
 * Provides tools for generating and validating ASCII animation frames.
 * Useful for terminal animation projects like the walking man.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";

export default function asciiArtHelper(pi: ExtensionAPI) {
  // Register a custom tool for generating walking frames
  pi.registerTool({
    name: "generate_ascii_frame",
    label: "Generate ASCII Frame",
    description: "Generate an ASCII art frame for animation (e.g., walking pose, running pose)",
    promptSnippet: "Generate ASCII art frames for terminal animations",
    promptGuidelines: [
      "Use this tool when creating or modifying ASCII animation frames.",
      "Frames should be compact (3-5 lines) and use standard ASCII characters."
    ],
    parameters: Type.Object({
      pose: Type.String({ 
        description: "The pose or action to depict (e.g., 'walking step 1', 'running', 'jumping')" 
      }),
      style: Type.Optional(Type.String({ 
        description: "Art style: 'simple' (basic stick figure), 'detailed' (more characters)",
        default: "simple"
      })),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const frames: Record<string, string> = {
        // Walking frames
        "walking step 1": `  O\n /|\\\n / \\`,
        "walking step 2": `  O\n /|\\\n /  \\`,
        "walking step 3": `  O\n /|\\\n  / \\`,
        "walking step 4": `  O\n /|\\\n / \\`,
        
        // Running frames
        "running": `  O\n /|\\  \n  / \\`,
        
        // Standing frames
        "standing": `  O\n /|\\\n / \\`,
        
        // Jumping
        "jumping": `  O  \n /|\\ \n  |  \n / \\`,
        
        // Waving
        "waving": `  O\n \\|/\n / \\`,
      };

      const key = params.pose.toLowerCase();
      let frame = frames[key];

      if (!frame) {
        // Generate a generic frame based on pose description
        if (params.style === "detailed") {
          frame = `  _O_\n   |  \n  /|\\\n   |  \n  / \\`;
        } else {
          frame = `  O\n /|\\\n / \\`;
        }
      }

      return {
        content: [{ 
          type: "text", 
          text: `Generated ASCII frame for "${params.pose}":\n\n\`\`\`\n${frame}\n\`\`\`\n\nLines: ${frame.split('\n').length}` 
        }],
        details: { frame, pose: params.pose },
      };
    },
  });

  // Register a tool to validate ASCII frames
  pi.registerTool({
    name: "validate_ascii_frames",
    label: "Validate ASCII Frames",
    description: "Validate multiple ASCII frames for consistent dimensions (important for smooth animation)",
    promptSnippet: "Validate ASCII animation frames have consistent dimensions",
    parameters: Type.Object({
      frames: Type.Array(Type.String(), { 
        description: "Array of ASCII art frames to validate" 
      }),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const { frames } = params;
      
      if (frames.length === 0) {
        return {
          content: [{ type: "text", text: "No frames provided to validate." }],
          details: { valid: false, issues: ["Empty frame list"] },
        };
      }

      const issues: string[] = [];
      const dimensions = frames.map((frame, i) => {
        const lines = frame.split('\n');
        const width = Math.max(...lines.map(l => l.length));
        const height = lines.length;
        return { frame: i, width, height };
      });

      // Check for consistent dimensions
      const firstWidth = dimensions[0].width;
      const firstHeight = dimensions[0].height;

      dimensions.forEach((dim, i) => {
        if (dim.width !== firstWidth) {
          issues.push(`Frame ${i}: width ${dim.width} (expected ${firstWidth})`);
        }
        if (dim.height !== firstHeight) {
          issues.push(`Frame ${i}: height ${dim.height} (expected ${firstHeight})`);
        }
      });

      const valid = issues.length === 0;
      const summary = valid 
        ? `✓ All ${frames.length} frames have consistent dimensions (${firstWidth}x${firstHeight})`
        : `✗ Found ${issues.length} dimension issues:\n  - ${issues.join('\n  - ')}`;

      return {
        content: [{ type: "text", text: summary }],
        details: { valid, issues, dimensions },
      };
    },
  });

  // Register a command to quickly preview frames
  pi.registerCommand("ascii-preview", {
    description: "Preview ASCII animation frames",
    handler: async (args, ctx) => {
      const sampleFrames = [
        `  O\n /|\\\n / \\`,
        `  O\n /|\\\n /  \\`,
        `  O\n /|\\\n  / \\`,
      ];

      ctx.ui.notify(`Sample frames (use generate_ascii_frame tool for custom poses)`, "info");
    },
  });
}
