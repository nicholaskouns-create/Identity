// Grid map engine: MapLibre GL 6 with the City flight-simulator tile registry
// (Esri World Imagery and hillshade, terrain DEM, NASA GIBS) plus live layers.
import * as maplibregl from '../lib/maplibre/maplibre-gl.mjs';

export const CONUS = [[-125.2, 23.8], [-66.4, 49.6]];
export const FUEL = {
  NUC: { label: 'Nuclear', color: '#f1e3b8' }, COL: { label: 'Coal', color: '#9a8574' }, NG: { label: 'Natural gas', color: '#ff9b54' },
  OIL: { label: 'Oil', color: '#d87e74' }, PET: { label: 'Petroleum coke', color: '#c46a5f' }, WAT: { label: 'Hydro', color: '#5aa9e6' },
  WND: { label: 'Wind', color: '#6edfd4' }, SUN: { label: 'Solar', color: '#ffd166' }, GEO: { label: 'Geothermal', color: '#e2a0e6' },
  BIO: { label: 'Biomass', color: '#9bc53d' }, WST: { label: 'Waste', color: '#7f9a54' }, BAT: { label: 'Battery storage', color: '#c1e8ce' },
  PS: { label: 'Pumped storage', color: '#3f86c6' }, SNB: { label: 'Solar + battery', color: '#f4b860' }, WNB: { label: 'Wind + battery', color: '#4fc1b6' },
  CHP: { label: 'Cogeneration', color: '#a0a8b0' }, OTH: { label: 'Other', color: '#7f8b90' }, OES: { label: 'Other storage', color: '#a7d9c1' }, UES: { label: 'Unknown storage', color: '#8fb3a3' },
};
const fuelMatch = ['match', ['get', 'fuel'], ...Object.entries(FUEL).flatMap(([k, v]) => [k, v.color]), '#7f8b90'];
const kvColor = ['step', ['coalesce', ['get', 'kv'], 0], '#3d6f88', 69, '#4f8fb0', 115, '#5fb3c9', 230, '#8fd3ff', 345, '#6edfd4', 500, '#f1e3b8', 735, '#ffffff'];

// Registry fallbacks mirror E47-Kartekeya/interfaces/skyrmion/world-registry.js.
export const TILE_SOURCES = {
  imagery: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  hillshade: 'https://server.arcgisonline.com/ArcGIS/rest/services/Elevation/World_Hillshade/MapServer/tile/{z}/{y}/{x}',
  labels: 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
  demTerrarium: 'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png',
  demJaxa: 'https://demotiles.maplibre.org/terrain-tiles/{z}/{x}/{y}.png',
};
export const NIGHT_CANDIDATES = [
  { id: 'VIIRS_Black_Marble', url: 'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/VIIRS_Black_Marble/default/2016-01-01/GoogleMapsCompatible_Level8/{z}/{y}/{x}.png', label: 'VIIRS Black Marble 2016' },
  { id: 'VIIRS_CityLights_2012', url: 'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/VIIRS_CityLights_2012/default/2012-01-01/GoogleMapsCompatible_Level8/{z}/{y}/{x}.jpg', label: 'VIIRS City Lights 2012' },
];
export function dnbCandidates(dateStr) {
  return ['VIIRS_SNPP_DayNightBand_At_Sensor_Radiance', 'VIIRS_SNPP_DayNightBand_ENCC', 'VIIRS_NOAA20_DayNightBand_At_Sensor_Radiance'].map((id) => ({
    id, url: `https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/${id}/default/${dateStr}/GoogleMapsCompatible_Level8/{z}/{y}/{x}.png`, label: `${id.replace(/_/g, ' ')} · ${dateStr}`,
  }));
}

const empty = () => ({ type: 'FeatureCollection', features: [] });

function baseStyle(imageryUrl, demUrl, demEncoding, nightUrl, dnbUrl) {
  return {
    version: 8,
    sources: {
      imagery: { type: 'raster', tiles: [imageryUrl], tileSize: 256, maxzoom: 19, attribution: 'Imagery © Esri, Maxar, Earthstar Geographics' },
      labels: { type: 'raster', tiles: [TILE_SOURCES.labels], tileSize: 256, maxzoom: 19, attribution: 'Boundaries & places © Esri' },
      night: { type: 'raster', tiles: [nightUrl], tileSize: 256, maxzoom: 8, attribution: 'Night lights: NASA GIBS / VIIRS' },
      dnb: { type: 'raster', tiles: [dnbUrl], tileSize: 256, maxzoom: 8, attribution: 'VIIRS Day/Night Band: NASA GIBS' },
      'dem-hill': { type: 'raster-dem', tiles: [demUrl], tileSize: 256, maxzoom: demEncoding === 'terrarium' ? 15 : 12, encoding: demEncoding, attribution: demEncoding === 'terrarium' ? 'Terrain Tiles (AWS Open Data; SRTM, NED, GMTED)' : 'AW3D30 © JAXA' },
      'dem-terrain': { type: 'raster-dem', tiles: [demUrl], tileSize: 256, maxzoom: demEncoding === 'terrarium' ? 15 : 12, encoding: demEncoding },
      states: { type: 'geojson', data: empty() },
      terminator: { type: 'image', url: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=', coordinates: [[-180, 85.0511], [180, 85.0511], [180, -85.0511], [-180, -85.0511]] },
      aurora: { type: 'geojson', data: empty() },
      alerts: { type: 'geojson', data: empty() },
      outages: { type: 'geojson', data: empty(), attribution: 'Outages: ODIN (DOE / ORNL)' },
      outagept: { type: 'geojson', data: empty() },
      perimeters: { type: 'geojson', data: empty() },
      lines: { type: 'geojson', data: empty(), attribution: 'Transmission lines: HIFLD (via DOE NETL)' },
      osm: { type: 'geojson', data: empty(), attribution: '© OpenStreetMap contributors' },
      plants: { type: 'geojson', data: empty(), attribution: 'Plants: WRI Global Power Plant Database (EIA-860)' },
      skyline: { type: 'geojson', data: empty() },
      fires: { type: 'geojson', data: empty() },
      quakes: { type: 'geojson', data: empty() },
      gpsacc: { type: 'geojson', data: empty() },
      patrol: { type: 'geojson', data: empty() },
    },
    sky: { 'sky-color': '#07131c', 'horizon-color': '#1d4b52', 'fog-color': '#060d11', 'fog-ground-blend': 0.55, 'horizon-fog-blend': 0.6, 'sky-horizon-blend': 0.7, 'atmosphere-blend': ['interpolate', ['linear'], ['zoom'], 0, 1, 7, 0.9, 11, 0] },
    layers: [
      { id: 'bg', type: 'background', paint: { 'background-color': '#03070a' } },
      { id: 'imagery', type: 'raster', source: 'imagery', paint: { 'raster-saturation': -0.12, 'raster-contrast': 0.06, 'raster-brightness-max': 0.95, 'raster-fade-duration': 250 } },
      { id: 'night', type: 'raster', source: 'night', layout: { visibility: 'none' }, paint: { 'raster-brightness-max': 1, 'raster-saturation': 0.15, 'raster-contrast': 0.12, 'raster-fade-duration': 250 } },
      { id: 'dnb', type: 'raster', source: 'dnb', layout: { visibility: 'none' }, paint: { 'raster-opacity': 0.85 } },
      { id: 'hillshade', type: 'hillshade', source: 'dem-hill', paint: { 'hillshade-exaggeration': 0.35, 'hillshade-shadow-color': 'rgba(0,0,0,0.55)', 'hillshade-highlight-color': 'rgba(255,255,255,0.08)', 'hillshade-accent-color': 'rgba(0,0,0,0.2)' } },
      { id: 'terminator', type: 'raster', source: 'terminator', paint: { 'raster-opacity': 0.82, 'raster-fade-duration': 0 } },
      { id: 'states-line', type: 'line', source: 'states', paint: { 'line-color': '#6edfd4', 'line-opacity': ['interpolate', ['linear'], ['zoom'], 3, 0.28, 8, 0.12], 'line-width': ['interpolate', ['linear'], ['zoom'], 3, 0.6, 8, 1.2] } },
      { id: 'labels', type: 'raster', source: 'labels', layout: { visibility: 'none' }, paint: { 'raster-opacity': 0.9 } },
      { id: 'aurora', type: 'heatmap', source: 'aurora', maxzoom: 9, layout: { visibility: 'none' }, paint: {
        'heatmap-weight': ['/', ['get', 'p'], 100], 'heatmap-intensity': 1.2, 'heatmap-radius': ['interpolate', ['linear'], ['zoom'], 2, 14, 6, 40],
        'heatmap-color': ['interpolate', ['linear'], ['heatmap-density'], 0, 'rgba(0,0,0,0)', 0.2, 'rgba(60,220,140,0.25)', 0.5, 'rgba(90,255,170,0.45)', 0.8, 'rgba(200,120,255,0.55)', 1, 'rgba(255,120,200,0.7)'], 'heatmap-opacity': 0.8 } },
      // Customers out by county (ODIN): colour and opacity on a log scale, 10 to 100,000.
      { id: 'outage-fill', type: 'fill', source: 'outages', layout: { visibility: 'visible' }, paint: { 'fill-color': ['interpolate', ['linear'], ['ln', ['+', 1, ['get', 'm']]], 0, '#ffd166', 4.6, '#ff9f43', 6.9, '#ff5f7a', 9.2, '#e0306f', 11.5, '#b3124f'], 'fill-opacity': ['interpolate', ['linear'], ['ln', ['+', 1, ['get', 'm']]], 0, 0.26, 6.9, 0.5, 11.5, 0.72] } },
      { id: 'outage-line', type: 'line', source: 'outages', layout: { visibility: 'visible' }, paint: { 'line-color': '#ffc2cf', 'line-width': ['interpolate', ['linear'], ['zoom'], 3, 0.4, 9, 1.4], 'line-opacity': 0.75 } },
      { id: 'outage-pulse', type: 'circle', source: 'outagept', layout: { visibility: 'visible' }, paint: { 'circle-color': '#ff5f7a', 'circle-opacity': 0, 'circle-stroke-color': '#ff8fa3', 'circle-stroke-width': 1.2, 'circle-stroke-opacity': ['interpolate', ['linear'], ['zoom'], 3, 0.85, 8, 0.4], 'circle-radius': ['interpolate', ['linear'], ['ln', ['+', 1, ['get', 'm']]], 4.6, 3, 9.2, 9, 11.5, 15] } },
      { id: 'alerts-fill', type: 'fill', source: 'alerts', layout: { visibility: 'visible' }, paint: { 'fill-color': ['get', 'color'], 'fill-opacity': 0.16 } },
      { id: 'alerts-line', type: 'line', source: 'alerts', paint: { 'line-color': ['get', 'color'], 'line-opacity': 0.8, 'line-width': 1.1 } },
      { id: 'perim-fill', type: 'fill', source: 'perimeters', layout: { visibility: 'none' }, paint: { 'fill-color': '#ff6b3d', 'fill-opacity': 0.32 } },
      { id: 'perim-line', type: 'line', source: 'perimeters', layout: { visibility: 'none' }, paint: { 'line-color': '#ffb38a', 'line-width': 1 } },
      { id: 'lines-glow', type: 'line', source: 'lines', layout: { 'line-cap': 'round', 'line-join': 'round', visibility: 'none' }, paint: { 'line-color': kvColor, 'line-width': ['interpolate', ['linear'], ['zoom'], 3, 3, 9, 7, 14, 12], 'line-blur': ['interpolate', ['linear'], ['zoom'], 3, 3, 12, 8], 'line-opacity': 0.32 } },
      { id: 'lines-core', type: 'line', source: 'lines', layout: { 'line-cap': 'round', 'line-join': 'round', visibility: 'none' }, paint: { 'line-color': kvColor, 'line-width': ['interpolate', ['linear'], ['zoom'], 3, ['step', ['coalesce', ['get', 'kv'], 0], 0.35, 345, 0.7, 500, 1.1], 10, ['step', ['coalesce', ['get', 'kv'], 0], 1, 345, 1.8, 500, 2.4], 15, 3.5], 'line-opacity': 0.95 } },
      { id: 'osm-line-glow', type: 'line', source: 'osm', filter: ['==', ['geometry-type'], 'LineString'], layout: { 'line-cap': 'round', visibility: 'visible' }, paint: { 'line-color': kvColor, 'line-width': 8, 'line-blur': 6, 'line-opacity': 0.35 } },
      { id: 'osm-line', type: 'line', source: 'osm', filter: ['==', ['geometry-type'], 'LineString'], layout: { 'line-cap': 'round', visibility: 'visible' }, paint: { 'line-color': kvColor, 'line-width': ['interpolate', ['linear'], ['zoom'], 10, 1.2, 16, 3.5] } },
      { id: 'osm-area', type: 'fill', source: 'osm', filter: ['==', ['geometry-type'], 'Polygon'], layout: { visibility: 'visible' }, paint: { 'fill-color': ['match', ['get', 'kind'], 'substation', '#6edfd4', 'plant', '#ffd166', '#c1e8ce'], 'fill-opacity': 0.28, 'fill-outline-color': '#c1e8ce' } },
      { id: 'osm-point', type: 'circle', source: 'osm', filter: ['==', ['geometry-type'], 'Point'], layout: { visibility: 'visible' }, paint: { 'circle-radius': ['interpolate', ['linear'], ['zoom'], 11, ['match', ['get', 'kind'], 'tower', 0.8, 'substation', 4, 'plant', 5, 2.5], 17, ['match', ['get', 'kind'], 'tower', 3, 'substation', 7, 'plant', 8, 4]], 'circle-color': ['match', ['get', 'kind'], 'substation', '#6edfd4', 'plant', '#ffd166', 'transformer', '#c1e8ce', '#bfe9ff'], 'circle-stroke-color': '#03070a', 'circle-stroke-width': 0.6 } },
      { id: 'plants-heat', type: 'heatmap', source: 'plants', maxzoom: 7, paint: {
        'heatmap-weight': ['interpolate', ['linear'], ['get', 'mw'], 0, 0, 50, 0.15, 1000, 0.7, 4000, 1], 'heatmap-intensity': ['interpolate', ['linear'], ['zoom'], 2, 0.7, 7, 1.6],
        'heatmap-radius': ['interpolate', ['linear'], ['zoom'], 2, 6, 7, 22], 'heatmap-opacity': ['interpolate', ['linear'], ['zoom'], 5, 0.75, 7, 0],
        'heatmap-color': ['interpolate', ['linear'], ['heatmap-density'], 0, 'rgba(0,0,0,0)', 0.15, 'rgba(110,223,212,0.18)', 0.4, 'rgba(193,232,206,0.38)', 0.7, 'rgba(241,227,184,0.6)', 1, 'rgba(255,246,220,0.85)'] } },
      { id: 'plants-glow', type: 'circle', source: 'plants', minzoom: 3.5, paint: { 'circle-color': fuelMatch, 'circle-radius': ['interpolate', ['linear'], ['zoom'], 4, ['*', 0.35, ['sqrt', ['get', 'mw']]], 10, ['*', 1.3, ['sqrt', ['get', 'mw']]]], 'circle-blur': 1, 'circle-opacity': ['interpolate', ['linear'], ['zoom'], 3.5, 0, 5, 0.45] } },
      { id: 'plants-core', type: 'circle', source: 'plants', minzoom: 3.5, paint: { 'circle-color': fuelMatch, 'circle-radius': ['interpolate', ['linear'], ['zoom'], 4, ['max', 0.8, ['*', 0.09, ['sqrt', ['get', 'mw']]]], 10, ['max', 2, ['*', 0.35, ['sqrt', ['get', 'mw']]]]], 'circle-stroke-color': 'rgba(3,7,10,0.8)', 'circle-stroke-width': 0.5, 'circle-opacity': ['interpolate', ['linear'], ['zoom'], 3.5, 0, 4.5, 0.95] } },
      { id: 'skyline', type: 'fill-extrusion', source: 'skyline', layout: { visibility: 'none' }, paint: { 'fill-extrusion-color': fuelMatch, 'fill-extrusion-height': ['get', 'h'], 'fill-extrusion-base': 0, 'fill-extrusion-opacity': 0.82, 'fill-extrusion-vertical-gradient': true } },
      { id: 'fires-glow', type: 'circle', source: 'fires', paint: { 'circle-color': '#ff6b3d', 'circle-radius': ['interpolate', ['linear'], ['ln', ['+', 2, ['get', 'acres']]], 0, 4, 12, 26], 'circle-blur': 1, 'circle-opacity': 0.55 } },
      { id: 'fires-core', type: 'circle', source: 'fires', paint: { 'circle-color': '#ffd0a8', 'circle-radius': ['interpolate', ['linear'], ['ln', ['+', 2, ['get', 'acres']]], 0, 1.5, 12, 5], 'circle-stroke-color': '#ff6b3d', 'circle-stroke-width': 1 } },
      { id: 'quakes', type: 'circle', source: 'quakes', paint: { 'circle-color': 'rgba(0,0,0,0)', 'circle-stroke-color': ['interpolate', ['linear'], ['get', 'mag'], 2.5, '#c9b6ff', 4.5, '#ff9bd2', 6, '#ff5f7a'], 'circle-stroke-width': 1.6, 'circle-radius': ['interpolate', ['exponential', 1.6], ['get', 'mag'], 2.5, 3, 7, 30] } },
      { id: 'patrol', type: 'line', source: 'patrol', paint: { 'line-color': '#ffffff', 'line-width': 2.5, 'line-dasharray': [2, 2], 'line-opacity': 0.9 } },
      { id: 'gpsacc', type: 'fill', source: 'gpsacc', paint: { 'fill-color': '#6edfd4', 'fill-opacity': 0.12, 'fill-outline-color': '#6edfd4' } },
    ],
  };
}

export class GridMap {
  constructor(container, { onError, onReady, worldSources } = {}) {
    this.onError = onError || (() => {});
    this.status = {};
    this.nightIndex = 0; this.dnbIndex = 0; this.demFallback = false;
    const imageryUrl = (worldSources && worldSources.imagery && worldSources.imagery.url_template) || TILE_SOURCES.imagery;
    this.dnbList = dnbCandidates(new Date(Date.now() - 36 * 3600e3).toISOString().slice(0, 10));
    this.map = new maplibregl.Map({
      container, style: baseStyle(imageryUrl, TILE_SOURCES.demTerrarium, 'terrarium', NIGHT_CANDIDATES[0].url, this.dnbList[0].url),
      bounds: CONUS, fitBoundsOptions: { padding: GridMap.padding() },
      maxPitch: 110, attributionControl: { compact: true }, hash: false, fadeDuration: 200, maxTileCacheZoomLevels: 6,
      canvasContextAttributes: { antialias: true, preserveDrawingBuffer: true }, cancelPendingTileRequestsWhileZooming: true,
    });
    this.map.addControl(new maplibregl.NavigationControl({ visualizePitch: true, showCompass: true }), 'top-right');
    this.map.addControl(new maplibregl.ScaleControl({ unit: 'imperial', maxWidth: 110 }), 'bottom-right');
    this.map.on('error', (e) => this.handleError(e));
    this.map.on('load', () => { this.ready = true; if (onReady) onReady(this); });
    this.gpsMarker = null;
  }

  static padding() {
    const w = window.innerWidth, wide = w > 860;
    return { top: 40, bottom: 80, left: wide ? Math.min(260, w * 0.2) : 16, right: wide ? Math.min(360, w * 0.26) : 16 };
  }

  handleError(e) {
    const id = e && (e.sourceId || (e.source && e.source.id));
    const msg = String((e && e.error && (e.error.message || e.error.status)) || 'tile error');
    if (!id) console.warn('[grid map]', msg);
    if (id === 'night') {
      this.status.night = { ok: false, msg };
      if (this.nightIndex + 1 < NIGHT_CANDIDATES.length && !this._nightSwitching) {
        this._nightSwitching = true; this.nightIndex += 1;
        setTimeout(() => { this.swapRaster('night', NIGHT_CANDIDATES[this.nightIndex].url); this._nightSwitching = false; }, 500);
      }
    } else if (id === 'dnb') {
      this.status.dnb = { ok: false, msg };
      if (this.dnbIndex + 1 < this.dnbList.length && !this._dnbSwitching) {
        this._dnbSwitching = true; this.dnbIndex += 1;
        setTimeout(() => { this.swapRaster('dnb', this.dnbList[this.dnbIndex].url); this._dnbSwitching = false; }, 500);
      }
    } else if ((id === 'dem-hill' || id === 'dem-terrain') && !this.demFallback) {
      this.demFallback = true; this.status.dem = { ok: false, msg: 'Terrarium tiles failed; using JAXA AW3D30 via MapLibre demo tiles' };
      this.swapDem(TILE_SOURCES.demJaxa, 'mapbox');
    } else if (id) {
      this.status[id] = { ok: false, msg };
    }
    this.onError(id, msg);
  }

  swapRaster(id, url) {
    const m = this.map; const st = m.getStyle(); const src = st.sources[id];
    const layers = st.layers.filter((l) => l.source === id);
    layers.forEach((l) => m.removeLayer(l.id));
    m.removeSource(id);
    m.addSource(id, { ...src, tiles: [url] });
    layers.forEach((l) => {
      const idx = st.layers.findIndex((x) => x.id === l.id);
      const before = st.layers.slice(idx + 1).find((x) => m.getLayer(x.id));
      m.addLayer(l, before && before.id);
    });
  }

  swapDem(url, encoding) {
    const m = this.map; const terrain = m.getTerrain();
    if (terrain) m.setTerrain(null);
    for (const id of ['dem-hill', 'dem-terrain']) {
      const st = m.getStyle(); const layers = st.layers.filter((l) => l.source === id);
      layers.forEach((l) => m.removeLayer(l.id));
      m.removeSource(id);
      m.addSource(id, { type: 'raster-dem', tiles: [url], tileSize: 256, maxzoom: 12, encoding, attribution: 'AW3D30 © JAXA' });
      layers.forEach((l) => m.addLayer(l, 'terminator'));
    }
    if (terrain) m.setTerrain({ source: 'dem-terrain', exaggeration: terrain.exaggeration || 1.35 });
  }

  set(id, data) { const s = this.map.getSource(id); if (s && s.setData) s.setData(data); }
  vis(layerIds, on) { for (const id of [].concat(layerIds)) if (this.map.getLayer(id)) this.map.setLayoutProperty(id, 'visibility', on ? 'visible' : 'none'); }
  paint(id, prop, v) { if (this.map.getLayer(id)) this.map.setPaintProperty(id, prop, v); }

  setScene(name) {
    const m = this.map; this.scene = name;
    const night = name === 'night', sat = name === 'satellite', terr = name === 'terrain', schem = name === 'schematic';
    this.vis('imagery', sat || terr);
    this.vis('night', night);
    this.paint('bg', 'background-color', schem ? '#061015' : '#03070a');
    this.paint('hillshade', 'hillshade-exaggeration', schem ? 0.6 : terr ? 0.45 : night ? 0.25 : 0.3);
    this.paint('hillshade', 'hillshade-shadow-color', schem ? 'rgba(0,0,0,0.75)' : 'rgba(0,0,0,0.55)');
    this.paint('hillshade', 'hillshade-highlight-color', schem ? 'rgba(110,223,212,0.22)' : night ? 'rgba(110,223,212,0.05)' : 'rgba(255,255,255,0.08)');
    this.paint('terminator', 'raster-opacity', sat || terr ? 0.82 : 0);
    this.paint('states-line', 'line-opacity', schem ? 0.55 : night ? 0.3 : 0.22);
    if (terr) {
      m.setTerrain({ source: 'dem-terrain', exaggeration: 1.4 });
      m.setSky({ 'sky-color': '#5b8fb8', 'horizon-color': '#cfe0ea', 'fog-color': '#a9bfcc', 'fog-ground-blend': 0.4, 'horizon-fog-blend': 0.5, 'sky-horizon-blend': 0.8, 'atmosphere-blend': ['interpolate', ['linear'], ['zoom'], 0, 1, 7, 0.8, 11, 0] });
      if (m.getPitch() < 40) m.easeTo({ pitch: 68, duration: 1400 });
    } else {
      if (!this.flying) m.setTerrain(null);
      m.setSky({ 'sky-color': '#07131c', 'horizon-color': night ? '#14363d' : '#1d4b52', 'fog-color': '#060d11', 'fog-ground-blend': 0.55, 'horizon-fog-blend': 0.6, 'sky-horizon-blend': 0.7, 'atmosphere-blend': ['interpolate', ['linear'], ['zoom'], 0, 1, 7, 0.9, 11, 0] });
    }
  }

  setGlobe(on) { this.map.setProjection({ type: on ? 'globe' : 'mercator' }); }

  fitConus() { this.map.fitBounds(CONUS, { padding: GridMap.padding(), pitch: 0, bearing: 0, duration: 1400 }); }

  setGps(p) {
    if (!p || !Number.isFinite(p.lat)) return;
    if (!this.gpsMarker) {
      const el = document.createElement('div'); el.className = 'gps-dot'; el.title = 'You are here (position stays on this device)';
      this.gpsMarker = new maplibregl.Marker({ element: el }).setLngLat([p.lon, p.lat]).addTo(this.map);
    } else this.gpsMarker.setLngLat([p.lon, p.lat]);
    if (Number.isFinite(p.accuracy_m)) this.set('gpsacc', circle([p.lon, p.lat], Math.max(10, p.accuracy_m)));
  }

  popup(lngLat, html) { return new maplibregl.Popup({ closeButton: true, maxWidth: '320px' }).setLngLat(lngLat).setHTML(html).addTo(this.map); }
}

export function circle([lon, lat], radiusM, steps = 64) {
  const pts = []; const R = 6371008.8;
  for (let i = 0; i <= steps; i++) {
    const b = (i / steps) * 2 * Math.PI, d = radiusM / R, la = lat * Math.PI / 180, lo = lon * Math.PI / 180;
    const la2 = Math.asin(Math.sin(la) * Math.cos(d) + Math.cos(la) * Math.sin(d) * Math.cos(b));
    const lo2 = lo + Math.atan2(Math.sin(b) * Math.sin(d) * Math.cos(la), Math.cos(d) - Math.sin(la) * Math.sin(la2));
    pts.push([lo2 * 180 / Math.PI, la2 * 180 / Math.PI]);
  }
  return { type: 'FeatureCollection', features: [{ type: 'Feature', geometry: { type: 'Polygon', coordinates: [pts] }, properties: {} }] };
}

/** Octagonal columns for the generation skyline: height ∝ nameplate MW. */
export function skyline(plants, minMw = 150) {
  const feats = [];
  for (const f of plants.features) {
    const mw = f.properties.mw; if (mw < minMw) continue;
    const [lon, lat] = f.geometry.coordinates;
    const r = 900 + 70 * Math.sqrt(mw), ring = [];
    for (let i = 0; i <= 8; i++) {
      const a = (i / 8) * 2 * Math.PI + Math.PI / 8;
      ring.push([lon + (r * Math.cos(a)) / (111320 * Math.cos(lat * Math.PI / 180)), lat + (r * Math.sin(a)) / 110574]);
    }
    feats.push({ type: 'Feature', geometry: { type: 'Polygon', coordinates: [ring] }, properties: { fuel: f.properties.fuel, mw, h: 18 * mw, name: f.properties.name } });
  }
  return { type: 'FeatureCollection', features: feats };
}

/**
 * Solar-illumination raster in Web Mercator (MODEL): alpha rises through civil,
 * nautical and astronomical twilight. Low-precision solar position (NOAA formulas).
 */
export function sunPosition(date = new Date()) {
  const rad = Math.PI / 180;
  const jd = date.getTime() / 86400000 + 2440587.5, n = jd - 2451545.0;
  const L = (280.46 + 0.9856474 * n) % 360, g = ((357.528 + 0.9856003 * n) % 360) * rad;
  const lambda = (L + 1.915 * Math.sin(g) + 0.02 * Math.sin(2 * g)) * rad;
  const eps = (23.439 - 0.0000004 * n) * rad;
  const decl = Math.asin(Math.sin(eps) * Math.sin(lambda));
  const ra = Math.atan2(Math.cos(eps) * Math.sin(lambda), Math.cos(lambda));
  const gmst = (280.46061837 + 360.98564736629 * n) % 360;
  let subLon = (ra / rad - gmst) % 360; if (subLon > 180) subLon -= 360; if (subLon < -180) subLon += 360;
  return { decl, subLon: subLon * rad, declDeg: decl / rad, subLonDeg: subLon };
}

export async function terminatorImage(date = new Date(), size = 1024) {
  const { decl, subLon } = sunPosition(date);
  const c = typeof OffscreenCanvas !== 'undefined' ? new OffscreenCanvas(size, size) : Object.assign(document.createElement('canvas'), { width: size, height: size });
  const ctx = c.getContext('2d'); const img = ctx.createImageData(size, size); const d = img.data;
  const sd = Math.sin(decl), cd = Math.cos(decl);
  for (let y = 0; y < size; y++) {
    const my = Math.PI * (1 - 2 * (y + 0.5) / size);
    const lat = Math.atan(Math.sinh(my)); const sl = Math.sin(lat), cl = Math.cos(lat);
    for (let x = 0; x < size; x++) {
      const lon = (x + 0.5) / size * 2 * Math.PI - Math.PI;
      const alt = Math.asin(sl * sd + cl * cd * Math.cos(lon - subLon)) * 180 / Math.PI;
      let a = 0; if (alt < 0.8) a = Math.min(1, (0.8 - alt) / 18.8);
      a = a * a * (3 - 2 * a);
      const o = (y * size + x) * 4;
      d[o] = 2; d[o + 1] = 6; d[o + 2] = 14; d[o + 3] = Math.round(232 * a);
    }
  }
  ctx.putImageData(img, 0, 0);
  return createImageBitmap(c);
}

export function haversine(a, b) {
  const R = 6371.0088, r = Math.PI / 180;
  const dLat = (b[1] - a[1]) * r, dLon = (b[0] - a[0]) * r;
  const s = Math.sin(dLat / 2) ** 2 + Math.cos(a[1] * r) * Math.cos(b[1] * r) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
}

export { maplibregl };
