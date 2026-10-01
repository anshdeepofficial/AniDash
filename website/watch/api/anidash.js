const API = 'https://core.justanime.to/api';

export default async function handler(req, res) {
  res.setHeader('Cache-Control', 's-maxage=60, stale-while-revalidate=300');
  const { action, query = '', id = '', episode = '1', audio = 'sub', page = '1' } = req.query;
  let path;
  if (action === 'search') path = `/search?query=${encodeURIComponent(query)}&page=${encodeURIComponent(page)}`;
  if (action === 'episodes' && /^\d+$/.test(id)) path = `/anime/${id}/episodes?page=${encodeURIComponent(page)}`;
  if (action === 'source' && /^\d+$/.test(id) && /^\d+(\.\d+)?$/.test(episode)) path = `/watch/${id}/episode/${episode}/megaplay`;
  if (!path) return res.status(400).json({ error: 'Invalid request' });
  try {
    const upstream = await fetch(`${API}${path}`, { headers: { Origin: 'https://justanime.to', Referer: 'https://justanime.to/', 'User-Agent': 'Mozilla/5.0 AniDash-PWA' } });
    const data = await upstream.json();
    if (!upstream.ok) return res.status(upstream.status).json({ error: 'Source unavailable' });
    if (action === 'source') {
      const selected = data[audio === 'dub' ? 'dub' : 'sub'];
      if (!selected?.sources?.length) return res.status(404).json({ error: `${audio.toUpperCase()} is unavailable` });
      return res.json({ ...selected, sources: selected.sources.map(source => ({ ...source, url: `/api/media?url=${encodeURIComponent(source.url)}` })), intro: selected.intro || data.intro, outro: selected.outro || data.outro });
    }
    return res.json(data);
  } catch (_) {
    return res.status(502).json({ error: 'The source service is temporarily unavailable' });
  }
}
