import type { Env } from "./types";
import { handleDiagramImage, handleSoloReading } from "./openai";
import { handleCreateInvite, handleInviteStatus, handleMatchReading } from "./pair";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const { method } = request;

    // Routing — bare-bones; swap for itty-router or hono if it grows.
    if (method === "POST" && url.pathname === "/v1/readings/solo") {
      return handleSoloReading(request, env);
    }
    if (method === "POST" && url.pathname === "/v1/images/diagram") {
      return handleDiagramImage(request, env);
    }
    if (method === "POST" && url.pathname === "/v1/invites") {
      return handleCreateInvite(request, env);
    }
    if (method === "POST" && url.pathname === "/v1/readings/match") {
      return handleMatchReading(request, env);
    }
    const m = url.pathname.match(/^\/v1\/invites\/([^/]+)\/status$/);
    if (method === "GET" && m) {
      return handleInviteStatus(m[1], env);
    }

    return new Response("Not found", { status: 404 });
  },
};
