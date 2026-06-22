// Vercel Serverless Function
// Purpose: return basic request information back to the same visitor.
// This function does NOT store data in a database and does NOT forward data anywhere.
// It is used by diagnostics.html to show the visitor their own public IP and request metadata.

export default function handler(request, response) {
  const forwardedFor = request.headers["x-forwarded-for"] || "";
  const ip = forwardedFor.split(",")[0]?.trim() || request.socket?.remoteAddress || "Unknown";

  response.setHeader("Cache-Control", "no-store, max-age=0");
  response.status(200).json({
    ip,
    country: request.headers["x-vercel-ip-country"] || "Unknown",
    region: request.headers["x-vercel-ip-country-region"] || "Unknown",
    city: request.headers["x-vercel-ip-city"] || "Unknown",
    timezone: request.headers["x-vercel-ip-timezone"] || "Unknown",
    userAgent: request.headers["user-agent"] || "Unknown",
    host: request.headers.host || "Unknown",
    note: "Returned to the same visitor only. This function does not store or forward data."
  });
}
