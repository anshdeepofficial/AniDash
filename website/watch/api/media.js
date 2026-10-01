const ALLOWED_HOSTS = ['nexabloom.top', 'give6beforegtav.site'];
const allowed = host => ALLOWED_HOSTS.some(domain => host === domain || host.endsWith(`.${domain}`));

export default async function handler(req, res) {
  try {
    const target = new URL(req.query.url || '');
    if (target.protocol !== 'https:' || !allowed(target.hostname)) return res.status(403).json({ error: 'Media host is not allowed' });
    const headers = { Origin: 'https://megaplay.buzz', Referer: 'https://megaplay.buzz/', 'User-Agent': req.headers['user-agent'] || 'Mozilla/5.0 AniDash-PWA' };
    if (req.headers.range) headers.Range = req.headers.range;
    const upstream = await fetch(target, { headers });
    if (!upstream.ok && upstream.status !== 206) return res.status(upstream.status).end();
    const type = upstream.headers.get('content-type') || '';
    if (type.includes('mpegurl') || target.pathname.endsWith('.m3u8')) {
      const playlist = await upstream.text();
      const rewritten = playlist.split('\n').map(line => {
        const value = line.trim();
        if (!value || value.startsWith('#')) return line;
        return `/api/media?url=${encodeURIComponent(new URL(value, target).toString())}`;
      }).join('\n');
      res.setHeader('Content-Type', 'application/vnd.apple.mpegurl');
      res.setHeader('Cache-Control', 'public, max-age=10');
      return res.status(200).send(rewritten);
    }
    for (const name of ['content-type', 'content-length', 'content-range', 'accept-ranges']) {
      const value = upstream.headers.get(name);
      if (value) res.setHeader(name, value);
    }
    res.setHeader('Cache-Control', 'public, max-age=3600');
    return res.status(upstream.status).send(Buffer.from(await upstream.arrayBuffer()));
  } catch (_) {
    return res.status(400).json({ error: 'Invalid media request' });
  }
}
