module.exports = async function handler(req, res) {
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("Content-Type", "application/json; charset=utf-8");

  const url = process.env.SB_URL || process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SB_SERVER_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;
  const adminKey = process.env.REPORTS_ADMIN_KEY;

  if (!url || !key) {
    res.status(500).json({ ok: false, error: "Missing Supabase server settings in Vercel." });
    return;
  }

  const tableUrl = url.replace(/\/$/, "") + "/rest/v1/device_reports";
  const headers = {
    apikey: key,
    Authorization: "Bearer " + key,
    "Content-Type": "application/json"
  };

  try {
    if (req.method === "POST") {
      const report = req.body;
      if (!report || typeof report !== "object") {
        res.status(400).json({ ok: false, error: "Report JSON is required." });
        return;
      }

      if (report.metadata?.consentBased !== true) {
        res.status(400).json({ ok: false, error: "Only visible consent-based reports are accepted." });
        return;
      }

      const row = {
        computer_name: report.system?.computerName || null,
        public_ip: report.network?.publicIp || null,
        os_caption: report.operatingSystem?.caption || null,
        cpu_name: Array.isArray(report.processor) ? report.processor[0]?.name || null : null,
        total_memory_gb: report.hardware?.totalMemoryGB || null,
        report: report
      };

      const save = await fetch(tableUrl, {
        method: "POST",
        headers: { ...headers, Prefer: "return=representation" },
        body: JSON.stringify(row)
      });

      const text = await save.text();
      if (!save.ok) {
        res.status(save.status).json({ ok: false, error: text });
        return;
      }

      res.status(201).json({ ok: true, saved: JSON.parse(text)[0] });
      return;
    }

    if (req.method === "GET") {
      const requestUrl = new URL(req.url, "https://" + req.headers.host);
      if (!adminKey || requestUrl.searchParams.get("key") !== adminKey) {
        res.status(401).json({ ok: false, error: "Admin key is required." });
        return;
      }

      const listUrl = tableUrl + "?select=id,created_at,computer_name,public_ip,os_caption,cpu_name,total_memory_gb,report&order=created_at.desc&limit=100";
      const list = await fetch(listUrl, { method: "GET", headers });
      const text = await list.text();
      if (!list.ok) {
        res.status(list.status).json({ ok: false, error: text });
        return;
      }

      res.status(200).json({ ok: true, reports: JSON.parse(text) });
      return;
    }

    res.status(405).json({ ok: false, error: "Method not allowed." });
  } catch (error) {
    res.status(500).json({ ok: false, error: error.message });
  }
};
