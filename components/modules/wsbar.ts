// Workspace-Leiste oben in der Bildschirmmitte (eine pro Monitor).
// Zeigt immer die Workspaces 1–5 plus jeden weiteren belegten, das aktive Feld leuchtet in der
// Palettenfarbe, belegte sind rot umrandet, leere gedimmt. Klick wechselt per scripts/ws (mit Glitch).
// Aktualisiert wird über refreshWsBar(), das core.ts bei Hyprland-Workspace-/Fenster-Events aufruft.
import { App, Window, Anchor, Layer, Exclusivity, DrawingArea, EventBox } from "./widget.ts"
import { execAsync } from "astal"
import { NEON, RGB, onColorChange } from "./colors.ts"
import { TITLE } from "./fonts.ts"
import { CYBER_DIR } from "../../env.ts"

const Cairo = (imports as any).cairo

const ALWAYS = 5            // diese Workspaces werden immer angezeigt
const TW = 34, TH = 20      // Kachelgröße (logische Pixel)
const GAP = 7, PAD_X = 64, BAR_H = 30

type MonState = { x: number, y: number, active: number }
let occupied = new Set<number>()
let monStates: MonState[] = []
const areas: { area: any, mon: any }[] = []

const rgb = (c: RGB, a = 1): [number, number, number, number] => [c[0] / 255, c[1] / 255, c[2] / 255, a]

const shown = (): number[] => {
  const ids = new Set<number>()
  for (let i = 1; i <= ALWAYS; i++) ids.add(i)
  for (const id of occupied) if (id > 0) ids.add(id)
  for (const m of monStates) if (m.active > 0) ids.add(m.active)
  return [...ids].sort((a, b) => a - b)
}

const activeFor = (mon: any): number => {
  try {
    const g = mon.get_geometry()
    const hit = monStates.find((m) => m.x === g.x && m.y === g.y)
    if (hit) return hit.active
  } catch {}
  return monStates[0]?.active ?? 1
}

// Kachel im HUD-Stil: Rechteck mit abgeschrägter rechter unterer Ecke
const tilePath = (ctx: any, x: number, y: number, w: number, h: number) => {
  const c = h * 0.38
  ctx.newPath()
  ctx.moveTo(x, y); ctx.lineTo(x + w, y); ctx.lineTo(x + w, y + h - c)
  ctx.lineTo(x + w - c, y + h); ctx.lineTo(x, y + h); ctx.closePath()
}

const text = (ctx: any, s: string, cx: number, cy: number, size: number, col: [number, number, number, number]) => {
  ctx.selectFontFace(TITLE, Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD)
  ctx.setFontSize(size)
  const e = ctx.textExtents(s)
  ctx.setSourceRGBA(...col)
  ctx.moveTo(cx - e.width / 2 - e.xBearing, cy - e.height / 2 - e.yBearing)
  ctx.showText(s)
}

const layout = (width: number) => {
  const ids = shown()
  const total = ids.length * TW + (ids.length - 1) * GAP
  const x0 = Math.round((width - total) / 2)
  return ids.map((id, i) => ({ id, x: x0 + i * (TW + GAP) }))
}

const draw = (area: any, mon: any, ctx: any) => {
  const w = area.get_allocated_width()
  const y = Math.round((BAR_H - TH) / 2)
  const act = activeFor(mon)
  const acc = NEON.badge, red = NEON.red, dim = NEON.dim
  const tiles = layout(w)

  // dünne Klammerlinie links/rechts wie die HUD-Rahmen
  if (tiles.length) {
    const l = tiles[0].x - 14, r = tiles[tiles.length - 1].x + TW + 14
    ctx.setLineWidth(1.2)
    ctx.setSourceRGBA(...rgb(red, 0.55))
    ctx.moveTo(l - 40, y + TH / 2); ctx.lineTo(l, y + TH / 2); ctx.lineTo(l, y); ctx.lineTo(l + 6, y); ctx.stroke()
    ctx.moveTo(r + 40, y + TH / 2); ctx.lineTo(r, y + TH / 2); ctx.lineTo(r, y + TH); ctx.lineTo(r - 6, y + TH); ctx.stroke()
  }

  for (const t of tiles) {
    const isAct = t.id === act, isOcc = occupied.has(t.id)
    if (isAct) {
      // Glow
      for (let g = 4; g >= 1; g--) {
        tilePath(ctx, t.x - g, y - g, TW + 2 * g, TH + 2 * g)
        ctx.setSourceRGBA(...rgb(acc, 0.07)); ctx.fill()
      }
      tilePath(ctx, t.x, y, TW, TH); ctx.setSourceRGBA(...rgb(acc, 0.92)); ctx.fill()
      text(ctx, String(t.id).padStart(2, "0"), t.x + TW / 2, y + TH / 2, 12, [0.02, 0.03, 0.05, 1])
    } else {
      tilePath(ctx, t.x, y, TW, TH)
      ctx.setSourceRGBA(0.02, 0.03, 0.05, isOcc ? 0.55 : 0.35); ctx.fillPreserve()
      ctx.setLineWidth(1.2)
      ctx.setSourceRGBA(...rgb(isOcc ? red : dim, isOcc ? 0.9 : 0.6)); ctx.stroke()
      text(ctx, String(t.id).padStart(2, "0"), t.x + TW / 2, y + TH / 2, 11, rgb(isOcc ? red : dim, isOcc ? 0.95 : 0.75))
      if (isOcc) { ctx.setSourceRGBA(...rgb(red, 0.9)); ctx.rectangle(t.x + 4, y + TH - 3, 6, 1.5); ctx.fill() }
    }
  }
  return false
}

export const refreshWsBar = () => {
  Promise.all([
    execAsync(["hyprctl", "workspaces", "-j"]),
    execAsync(["hyprctl", "monitors", "-j"]),
  ]).then(([ws, mons]) => {
    try {
      occupied = new Set(JSON.parse(ws).filter((w: any) => w.id > 0 && w.windows > 0).map((w: any) => w.id))
      monStates = JSON.parse(mons).map((m: any) => ({ x: m.x, y: m.y, active: m.activeWorkspace?.id ?? 1 }))
    } catch {}
    for (const a of areas) { try { a.area.queue_draw() } catch {} }
  }).catch(() => {})
}

export const WsBarWindows = () => {
  const monitors = Array.from((App as any).get_monitors())
  monitors.forEach((mon: any, i: number) => {
    const area = DrawingArea({})
    area.set_size_request(-1, BAR_H)
    area.connect("draw", (_w: any, ctx: any) => draw(area, mon, ctx))
    const box = EventBox({ child: area })
    box.connect("button-press-event", (_w: any, ev: any) => {
      try {
        const [, x] = ev.get_coords()
        const hit = layout(area.get_allocated_width()).find((t) => x >= t.x && x <= t.x + TW)
        if (hit) execAsync(["sh", "-c", `'${CYBER_DIR}/scripts/ws' go ${hit.id}`]).catch(() => {})
      } catch {}
      return true
    })
    areas.push({ area, mon })
    Window({
      name: `wsbar-${i}`,
      className: "aug wsbar",
      gdkmonitor: mon,
      anchor: Anchor.TOP | Anchor.LEFT | Anchor.RIGHT,
      exclusivity: Exclusivity.EXCLUSIVE,
      layer: Layer.TOP,
      child: box,
    })
  })
  onColorChange(() => { for (const a of areas) { try { a.area.queue_draw() } catch {} } })
  refreshWsBar()
}
