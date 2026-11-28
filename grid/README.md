# Grid

## Multimodal Radar / environmental feed observatory

[**Open standalone radar and overlays**](https://nicholaskouns-create.github.io/Identity/grid/radar/) · [Companion Radar instrument](https://nicholaskouns-create.github.io/Radar/doppler/) · [Radar provenance guide](https://github.com/nicholaskouns-create/Radar/blob/main/MULTIMODAL.md).

Grid's MRMS reflectivity layer now cross-links independently switchable USGS earthquakes, NIFC wildfire incidents, NWS warning polygons, NOAA SWPC aurora forecast and published generating plants. Browser-local named presets retain layer choices and map view. Derived overlays count plant–earthquake/fire proximity and plant-in-warning-polygon intersections without implying causal damage, current generation output, Doppler velocity, or measured complex I/Q.


**Live U.S. power-grid monitor with a certified spectral auditor.**
Open it at **https://nicholaskouns-create.github.io/Identity/grid/**. It runs entirely in the browser, installs as an app, and keeps working offline on its last certified state.

Grid reads public publishers directly where they allow browser access, and through a scheduled relay where they do not. It draws the grid on night-light, satellite and 3D terrain maps that you can fly from your own GPS position. Beside the map, the certified auditor from the *certified spectral monitor* specification runs on the IEEE 14-bus and 118-bus systems. Their operating point is driven by live U.S. demand, and a corrupted runtime topology file is refused, not passed.

![Grid](og-grid.png)

## Views

| Tab | What it shows |
|---|---|
| **At a glance** | A strip across the top of the map: national load, Texas grid frequency, customers without power (red when your own county is out), river gauges in flood, whether your alerts are on, severe-weather warnings, the geomagnetic Kp index and the auditor's state. Tapping any of them opens its panel; tapping the outage figure also frames every affected county on the map. |
| **Alerts** | A notification on your phone or computer when the power goes out in a county you choose, when it comes back, and when the National Weather Service issues a severe or extreme warning there. It works with Grid closed. See [Alerts](#alerts). |
| **Water** | The water system that serves your position and how it stands with EPA, drought in your county, rivers at flood stage across the country and near you, and the water systems in the counties where the power is out. See [Water](#water). |
| **Search** | Press **/** or tap ⌕. It searches all 3,231 counties, every state, every utility now reporting outages and all 9,833 power plants on the device as you type, and cities and addresses through OpenStreetMap when you ask. Choosing a result flies there. |
| **Map** | Night-light, satellite and terrain scenes on a globe. Layers: power outages by county (ODIN), rivers at flood stage (NOAA), your water system's service area (EPA), transmission lines (HIFLD), the local grid around you (OpenStreetMap), 9,833 generating plants and a 3D generation skyline, severe-weather warnings, wildfires and perimeters, earthquakes, the auroral oval, last night's VIIRS Day/Night Band, the day–night terminator. Side panels show Lower-48 demand, fuel mix, operator load, water, space weather, the hazard exposure at your position, and the auditor. |
| **Fly** | The map as a flight instrument, using the same imagery registry as the City flight simulators. Flight starts about 13,000 ft above the ground with **altitude hold** on, so the aircraft flies level on its own; ▲ / ▼ on screen (R / F on a keyboard) move the held altitude 2,000 ft. Pushing the stick (W/S) flies by hand, and letting go holds the altitude you are at. A/D roll, Q/E yaw, Z/X throttle, **P** flies the nearest transmission line, Esc exits. The HUD shows heading, ground speed, altitude, height above terrain, the held altitude and position. It also names the nearest plant and the nearest line, and flags any active weather warning over the aircraft. |
| **Auditor** | Five replicas, five pipelines and the hash-chained decision ledger, live. You can inject each fault class (L0, CM2, H1, E1, CM6) and watch every pipeline decide. You can also run the acceptance protocol in a worker and compare it with the Python reference. |
| **Formalism** | The window Λ, the gap g, the envelope ε₀ and the tolerance τ for each system, with every inertia count of the exact certificate recomputed over ℚ in the browser. Also the E47 reference instantiation computed live and checked against the City's E47 lock. |
| **Sources** | Every source with its publisher, evidence class, status and age. Also the EIA key, alerts, wall mode, install, and the doorway survey. |

## Evidence grammar

Every number carries one of six marks, so a reading is never presented as more than it is.

| Mark | Class | Meaning |
|:-:|---|---|
| ● | Live | Fetched from the publisher in this session |
| ◆ | Relay | Fetched server-side by the Grid relay (GitHub Actions) and served as a snapshot with its generation time |
| ■ | Published | Fixed published dataset, version stated |
| △ | Model | Computed in this browser from live inputs and stated formulas |
| ○ | Simulated | Synthetic perturbation or injected fault (auditor benchmark) |
| ✦ | Certified | Exact arithmetic against a SHA-256-pinned certificate |

When a source is down, its panel says so. Nothing is filled in.

## Outages and frequency

**Customers without power, county by county.**
- **Source.** The outage layer and panel read ODIN, the Outage Data Initiative Nationwide run by the Department of Energy and Oak Ridge National Laboratory. Its public feed gives each active outage's county, the customers (meters) affected, the utility, when it started and the estimated restoration time.
- **Coverage.** ODIN covers the utilities that report to it: about 160 utility feeds, which the panel counts live. Utilities outside ODIN do not appear, so an empty county is not proof that the power is on.
- **Your county.** Grid finds your county from your GPS position and tells you when it has an outage.

**Who depends on the power.** The HHS emPOWER Program publishes, for every county, how many Medicare beneficiaries have claims for electricity-dependent medical equipment: ventilators, oxygen concentrators, home dialysis, enteral feeding and infusion pumps, powered wheelchairs and beds, cardiac assist devices.
- **On the map.** Each outage county's popup shows that count beside the customers out, with how many of those people also rely on facility dialysis, oxygen service, home health or hospice at home.
- **In the panel.** The panel adds up the people who rely on powered equipment in every county with 1,000 or more customers out, and marks each county in the list with ⚕ and its count.
- **Limits.** The counts are Medicare only (Fee-for-Service and Medicare Advantage), so people on other insurance are not counted. To protect privacy HHS shows any ZIP Code with 1 to 10 people as 11 before summing counties, so small counts run slightly high. HHS refreshes the data monthly, and Grid shows its month.

**Generators and carbon monoxide.** When your county is out, the panel shows the CDC and CPSC guidance with the outage: run a generator outdoors only, at least 20 feet from doors, windows and vents, never in a home, garage, basement or carport; keep battery-powered CO alarms on; and get outside and call 911 if an alarm sounds or anyone has symptoms. Every outage popup and every outage notification carries the short form.

**Grid frequency, live.** ERCOT publishes the Texas Interconnection's frequency, time error and inertia on its real-time conditions page. The panel shows:
- the frequency;
- its deviation from 60 Hz against the ±30 mHz normal band and the ±90 mHz ACE limit;
- the last 45 minutes as a trace;
- Texas demand, wind and solar.

The Eastern and Western Interconnections do not publish a live public frequency; FNET/GridEye's public display runs on sample data.

**Disturbances.** A generation or transmission loss writes itself into system frequency, and the trace above is enough to say that something went, which way, and how deep. The panel reads it and reports the most recent event in the window.
- **What counts.** A step larger than ±34 mHz between consecutive readings, after a quiet run-up. That figure is the governor deadband for steam and hydro turbines with mechanical governors (NERC BAL-001-TRE-2 R6.1), the wider of the two published deadbands: below it no governor is obliged to respond, so smaller motion is regulation rather than a disturbance. A ramp is not a step, and the run-up has to be flat to within the ±17 mHz standard deadband, so a slow drift never reports as an event.
- **How deep.** The nadir against ERCOT's own bands: the ±30 mHz normal band, the ±90 mHz ACE limit, and the load-shedding stages, where 59.3 Hz sheds at least 5% of Transmission Operator load, 58.9 Hz at least 15% cumulative and 58.5 Hz at least 25% (ERCOT, Transmission Operator UFLS obligations). The stages are cumulative, so the panel reports the deepest one reached rather than the first one crossed.
- **How large.** ERCOT publishes system inertia in the same feed, so the swing equation **ΔP = 2·H·(df/dt)/f₀** gives a figure in megawatts. Grid states it as **a floor and never an estimate**: sampling every ten seconds averages away the steepest part of the fall, and governors are arresting it inside that same interval, so both errors push the same way and the true imbalance is larger — often several times larger. When ERCOT does not publish inertia with a reading, no size is given at all, because a number without H would be invented.
- **A gap is never an event.** If the feed stops and returns at a different frequency, the jump across the gap is discarded. The same rule the outage alerts follow: a reading that cannot be trusted reads as unknown, never as a number.
- **What it cannot say.** It cannot name a line. Breaker position is utility-internal SCADA, protected under NERC CIP and published nowhere, at any latency, so no feature can reach it. A detection here says the Texas Interconnection lost or gained something — not which line, unit or substation. Where an outage follows, the counties appear in the outage panel. A quiet trace is also not proof that nothing happened: an event can arrive and be corrected between two readings.
- **Where it runs.** `grid/engine/disturbance.js`, in the browser from live inputs, which is why it carries △ Model rather than ◆ Relay. Tests in `grid/engine/disturbance.test.mjs`.

**Your outlet.** The frequency of whichever interconnection you are on is present in the hum of the wiring around you: chargers, power strips, lamps and transformers.
- **How it is measured.** *Measure at your outlet* asks for the microphone, mixes the sound with 60, 120, 180, 240, 300 and 360 Hz references on the device (an AudioWorklet), and reads the frequency from how fast each harmonic's phase turns. Harmonics are combined by inverse variance.
- **What counts as hum.** Hum counts only when its phase is coherent, its level is steady, it implies a grid within 0.25 Hz of 60, and its harmonics agree. Beeps, speech and music produce no reading.
- **Precision.** Tested on synthetic hum at 44.1, 48 and 96 kHz: within 0.25 mHz with the 60 Hz fundamental present, and within 0.5 mHz from the 120 and 180 Hz overtones alone, which matters on phones that filter out 60 Hz (`node grid/engine/enf.test.mjs`).
- **Absolute accuracy.** The device's audio clock adds a fixed offset, typically under ±3 mHz.
- **Privacy.** The sound never leaves the device.

**The edge function.** ERCOT and ODIN do not allow browsers to read them directly, and emPOWER's county table is large, so Grid reads them through `grid-live`, a Supabase Edge Function in the City's project. The water sources go through it too (see [Water](#water)). Its source is `tools/grid/supabase/grid-live/index.ts`, with tests in `tools/grid/test_grid_live.mjs`.
- **Fixed upstreams.** Its sources are fixed in the code. The only request value that reaches a publisher's URL is a county code, checked to be exactly five digits, and county lookups that miss the cache are capped at 40 a minute per instance.
- **Caching.** Each instance caches ERCOT for 8 seconds, ODIN for 60, river gauges for 10 minutes, a county's drought for 6 hours, a county's water systems for 24 hours and emPOWER for 12 hours, so the publishers see one read per interval however many people have Grid open. Grid also keeps the emPOWER table on the device for 12 hours.
- **Freshness.** Grid polls it every 10 seconds for frequency and every 60 for outages. The panels show the age of each reading.

## Mass-energy

**What the electricity in the grid weighs.** E = mc², read backwards, on numbers already on the page. Two quantities, kept apart because conflating them is the whole trap in this subject.

- **Stored.** ERCOT publishes system inertia in MW·s: the kinetic energy turning in the synchronous machines at this instant. Divided by c² that is a mass, and it is the only figure here that is actually *in* the grid. At a typical 320 GW·s the Texas Interconnection carries **3.56 mg** of mass-energy in its spinning fleet.
- **Flowing.** Demand is power, joules per second, so divided by c² it is a mass *rate* — kilograms per second, not a weight, and not sitting anywhere. Texas runs about 668 µg/s and the Lower 48 about 5.34 mg/s, which is 169 kg over a year. The panel labels the row *a rate, not a weight* and never sums it into the stored figure.
- **Ride-through.** Stored divided by flowing has units of time, and the number it lands on is the inertia constant H/S that power engineers already use — c² cancels out of the ratio, so this is a standard quantity reached from the other side. About **5.3 s** at typical inertia. Wind and solar are inverter-based and add no synchronous inertia, so as their share rises this figure falls: at 250 GW·s it is 4.8 s, and the same megawatt loss then produces a steeper rate of change of frequency, which is exactly what the disturbance reading measures.
- **The grid does not get heavier.** Electricity passes through and leaves as heat; nothing accumulates in the wires. Rest mass genuinely is converted, but at the generator, where burning fuel leaves the fuel lighter — upstream of anything Grid can see.
- **Coverage.** Inertia covers rotating machines only. Field energy in lines, transformers and reactors is also stored, also real, and published by nobody, so the stored figure is a floor on the grid's true instantaneous energy content. When ERCOT publishes no inertia, no stored figure is given and the flow rate is not offered as a substitute.
- **Where it runs.** `grid/engine/massenergy.js`, in the browser from live inputs, which is why it carries △ Model. Tests in `grid/engine/massenergy.test.mjs`.

## Water

**Your water system.** Once you allow location, the Water panel names the water system that serves your position and shows how it stands with EPA.
- **Which system.** EPA's national map of public water system service areas (version 3, March 2026) holds a boundary for most community water systems. Some boundaries come from the water systems and states, and EPA modeled the rest; the panel says which. Grid asks the map with a box about 2 km across around you and finds the boundary that holds your position on the device. Where boundaries overlap, as a wholesaler's does with the towns it sells to, the smallest one holding you is yours and the others are listed.
- **How it stands.** EPA ECHO's Drinking Water System Search, over the federal Safe Drinking Water Information System, gives every active community water system serving your county. The panel shows the population it serves, its source water, and ECHO's compliance fields in ECHO's own terms: violations in the latest quarter and the contaminants involved, the quarters in violation over the past three years (of 12), whether EPA treats it as an enforcement priority, and whether health-based violations are on record. States report quarterly, and the federal copy can trail by three to six months.
- **No boundary at your position.** Homes on private wells and some small systems are not mapped. The panel then lists your county's systems, largest first, with how each stands.

**Boil-water notices.** No national feed of boil-water notices exists: each water system or state issues its own, by text or phone, on local news or on the utility's website. Grid cannot show them, and says so. The panel carries the CDC's guidance: bring clear water to a rolling boil for 1 minute (3 minutes above 6,500 feet); use bottled or boiled water for drinking, cooking and brushing teeth, and ready-to-use formula for babies if possible; boiling does not remove chemicals, so a do-not-drink notice means bottled water.

**Water where the power is out.** Water systems pump and treat with electricity, and a loss of pressure can lead to a boil-water notice. For the three counties with the most customers out (1,000 or more), the panel shows how many community water systems serve them and how many people. When your own county has 1,000 or more customers out, your water card says that pressure can drop.

**Rivers at flood stage.** NOAA's National Water Prediction Service publishes every river gauge's latest stage and flood category; NOAA refreshes it every 30 minutes, and most stages come from USGS stream gauges.
- **On the map.** Every gauge at action stage or above is a drop in the National Weather Service flood colours: yellow near flood stage, orange minor, red moderate, purple major. Each popup gives the stage, the threshold it has passed, and a link to the gauge's NOAA hydrograph and forecast. Where NOAA's thresholds for a gauge do not fit its reading, as at some lake gauges recorded on a different scale, the flood category is shown without a number.
- **In the panel.** Counts by category, the worst gauges, and whether any gauge within 50 miles of you is at or near flood stage.

**Drought.** The U.S. Drought Monitor's county statistics for the latest weekly map: the share of your county in drought (D1 to D4) and the worst category present.

**Through the edge function.** Rivers, county water systems and drought come through `grid-live` (`?src=rivers`, `?src=water&fips=`, `?src=drought&fips=`). Your water system's boundary comes straight from EPA's map service.

## Alerts

Grid can tell you when the power goes out where you or your family live, with Grid closed.

**What you get.**
- **Power out.** A notification when the customers out in one of your counties reaches your threshold: any outage at all, or 10, 100, 1,000 or 10,000 customers. It names the utility and its restoration estimate, and carries the generator warning.
- **Follow-ups** (the second switch). Grid never says the power is restored: a utility's report can lag what is true at your address, so every follow-up points you to the utility.
  - **Reported outages down to N.** Sent once when the count falls below half your threshold, with the number still out.
  - **No outages reported.** Sent when the utility's newer reports show none in the county on two checks in a row. If your power is still out, report it: the utility may not know about your address.
  - **Outage data unavailable.** Sent once if, during an alert, Grid cannot trust the data for 15 minutes. That happens when ODIN does not answer, answers in an unexpected form, or the utility's own feed is in error or has sent nothing newer. This notice is sent even with the switch off.
- **Severe weather.** A notification when the National Weather Service issues a severe or extreme warning for one of your counties: tornado, severe thunderstorm, flash flood, hurricane, winter storm, ice storm, extreme heat or cold, high wind, and the like. Watches, advisories and statements stay in the app.
  - **One warning, one notice.** Each warning is known by its NWS identity: the VTEC event, or the earlier messages an update references. A continued or extended warning does not notify you twice.
  - **Separate warnings.** A second, separate warning of the same kind in the same county is a new notification.
- **Official alerts.** Keep your phone's government emergency alerts on as well. Grid adds to them and does not replace them.
- **Counties.** Up to five per device: your own, found from your position, and any others you add by county or by town.
- **Tapping a notification** opens Grid at that county.

**Turning it on.** Tap **🔔 Alerts** in the top bar (or **Alert me about outages in …** under your GPS position), choose the counties, and tap **Turn on alerts**. **Send a test alert** sends one about 15 seconds later, so you can lock the phone or close Grid first. Tapping it should open your first county.
- **iPhone and iPad.** Alerts work when Grid is on the Home Screen: in Safari tap Share, then **Add to Home Screen**, then open Grid from the new icon and turn alerts on there. iOS and iPadOS 16.4 or later.
- **Android, Windows, macOS and Linux.** Chrome, Edge, Firefox and Samsung Internet work directly. Safari on macOS 13 or later does too.

**Powered medical equipment at home.** A switch in the Alerts panel for households where someone relies on electricity for medical equipment.
- **What it changes.** It sets alerts to any outage at all, with power-back notices on.
- **The plan.** It shows a checklist: tell the utility (medical lists bring warnings before planned shutoffs, but no promise of faster restoration); know battery hours; keep backup oxygen; write down settings and numbers; check how long cold-stored medicines keep; know the dialysis center's emergency plan; decide where to go if the outage outlasts the batteries; and put CO alarms near sleeping areas.
- **When your county is out.** The outage panel shows what to do now, with the generator warning.
- **Privacy.** The switch and the checklist are kept only on the device. Grid's server never learns that anyone in the household uses medical equipment.

**How it works.** Standard Web Push, with no app-store account and no third-party push service of Grid's own.
- **The service.** `grid-alerts`, a Supabase Edge Function in the City's project (`tools/grid/supabase/grid-alerts`). Every five minutes a `pg_cron` job asks it to read ODIN and the Weather Service's active warnings, compare them with each subscriber's counties, and send what is due through the browser's own push service (Google, Apple, Mozilla or Microsoft).
- **Encryption and signing.** Messages are encrypted to the device (RFC 8291) and signed with Grid's application server key (VAPID, RFC 8292), on WebCrypto with no third-party code. `node tools/grid/test_grid_alerts.mjs` checks the encryption byte for byte against the `http_ece` reference, checks the signatures with an independent verifier, and runs the whole service against recorded-format fixtures.
- **Fail-safe rules.**
  - **Smaller counts must be confirmed.** A smaller count is believed only when every utility that stopped reporting outages in the county has sent ODIN a newer report without an error (ODIN's feed status). Anything else, including a response that is valid JSON but not ODIN's feed, reads as "cannot be trusted", never as zero.
  - **Delivery is tracked per notice.** A notice the push service cannot take for now is sent again on the next check while it still applies, even if other notices in the same check went through. Subscriptions a push service reports gone are deleted.
- **Notifications turned off in settings.** If notifications for Grid are later turned off, Grid shows alerts as off, says why, and deletes the server copy until you turn them on again.
- **Only push services are contacted.** A subscription is accepted only if its address belongs to a browser push service, so the alert sweep can never be pointed at any other address.

**What is stored, and where.**
- **On Grid's server**, for each device with alerts on: the push address and its two public keys, the counties, the threshold, the two on/off choices, and a record of what has been sent so nothing repeats. No name, email, IP address, precise location or health information. Turning alerts off deletes the record.
- **On the device:** your choices, the medical-equipment switch and the checklist.

**What alerts cannot do.** ODIN covers the utilities that report to it, so an outage at a utility outside ODIN never produces a notification. Utility feeds and push delivery can each add minutes. Grid is an independent public-data tool, not your utility or an emergency service: report outages to your utility, and in an emergency call 911.

## Sources

| Source | Publisher | Class | Refresh |
|---|---|:-:|---|
| Planetary K-index, 1-minute and 3-hour | NOAA Space Weather Prediction Center | ● | 1 min |
| Space-weather scales G/S/R | NOAA SWPC | ● | 5 min |
| Space-weather alerts, watches, warnings | NOAA SWPC | ● | 5 min |
| OVATION aurora probability | NOAA SWPC | ● | 15 min |
| Active power outages by county | ODIN (DOE / ORNL) public feed, via `grid-live` | ◆ | 1 min |
| Real-time frequency, time error, inertia, demand, wind, solar (Texas) | ERCOT Real-Time System Conditions, via `grid-live` | ◆ | 10 s |
| Your outlet's frequency (on request) | This device's microphone; nothing leaves it | ● | 0.1 s |
| Frequency disturbances (Texas) | Computed here from the ERCOT trace and published inertia; deadbands from NERC BAL-001-TRE-2, load-shed stages from ERCOT | △ | 10 s |
| Mass-energy of the grid: stored and flowing | Computed here as E/c² from ERCOT inertia and EIA-930 / ISO demand | △ | 10 s |
| Medicare beneficiaries who rely on electricity-dependent medical equipment, by county | HHS emPOWER Program (CMS, HHS) public REST service, via `grid-live` | ◆ | monthly (HHS); 12 h cache |
| River gauges at or near flood stage | NOAA National Water Prediction Service, via `grid-live` | ◆ | 30 min (NOAA); 10 min cache |
| Community water systems by county, with EPA compliance status | EPA ECHO Drinking Water System Search (SDWIS/Fed), via `grid-live` | ◆ | quarterly (states); 24 h cache |
| Your water system's service area (with your location) | EPA public water system service areas | ● | once per place |
| Drought in your county (with your location) | U.S. Drought Monitor (NDMC, USDA, NOAA), via `grid-live` | ◆ | weekly; 6 h cache |
| Background alerts for your counties (on request) | `grid-alerts` over Web Push, reading ODIN and the NWS | ● | 5 min |
| County boundaries (1:10m) | U.S. Census Bureau via us-atlas 3.0.1 | ■ | fixed |
| Place search (on request) | OpenStreetMap Nominatim | ● | on request |
| Severe and extreme weather alerts | National Weather Service API | ● | 2 min |
| Earthquakes M2.5+, past day | USGS Earthquake Hazards Program | ● | 2 min |
| Wildland fire incidents | NIFC WFIGS | ● | 10 min |
| Wildland fire perimeters | NIFC WFIGS | ● | 15 min |
| Transmission lines | HIFLD via DOE NETL ArcGIS | ● | on view |
| Local power infrastructure | OpenStreetMap via Overpass | ● | on request |
| EIA-930 hourly demand, forecast, generation by fuel, interchange | U.S. EIA API v2 (free key) | ● | 10 min |
| ISO/RTO real-time load and fuel mix: CAISO, ERCOT, ISO-NE, MISO, NYISO, SPP, and PJM with a key | Grid relay: GitHub Actions + `gridstatus` | ◆ | 10 min |
| World imagery, hillshade, boundaries | Esri | ● | tiles |
| Terrain elevation (Terrarium) | AWS Open Data Terrain Tiles; JAXA AW3D30 fallback | ■ | tiles |
| VIIRS Black Marble and daily Day/Night Band | NASA GIBS | ● | daily |
| 9,833 U.S. generating plants | WRI Global Power Plant Database v1.3.0 (EIA-860) | ■ | fixed |
| IEEE 14-bus and 118-bus systems | MATPOWER case files via PYPOWER 5.1.21 | ■ | fixed |

Privacy: your GPS position stays on your device. Parts of it leave in three forms only: the bounding box of an Overpass query for the local grid; a box about 2 km across sent to EPA's service-area map to find your water system; and your county's five-digit code, sent to `grid-live` for its water systems and drought. The EIA key is stored in your browser and sent only to `api.eia.gov`. With alerts on, Grid's server keeps your device's push address, your counties and your alert choices, and nothing else; see [Alerts](#alerts).

## The relay

Several operators do not allow browser access. For them, `.github/workflows/grid-live.yml` runs every 10 minutes:

1. It installs `gridstatus` 0.37.0.
2. It fetches each operator's public endpoint, plus EIA-930 when a key is present.
3. It keeps a rolling 24-hour history.
4. It force-pushes `live.json` and `door.json` to the orphan branch **`grid-live`**. That branch has no history, so it never grows.

Grid reads the snapshot from `raw.githubusercontent.com`. The doorway on every City page shows a one-line reading from `door.json`.

**Turning it on in the GitHub website:**

1. Get a free EIA key at https://www.eia.gov/opendata/register.php. It arrives by email within a minute.
2. Open the **Identity** repository and go to **Settings → Secrets and variables → Actions → New repository secret**. Set **Name** to `EIA_API_KEY`, paste the key, and click **Add secret**. If you have a PJM Data Miner key, add it the same way as `PJM_API_KEY`.
3. Go to **Actions → Grid live relay → Run workflow → Run workflow**.
4. When the run turns green, a `grid-live` branch appears. Grid picks it up within five minutes, and the schedule keeps it fresh after that.

Without the secret, the relay still publishes the ISO/RTO data. The EIA panel then reads the key from the browser instead (**Sources → EIA-930 key**).

## The certified auditor

**System.** A is the DC susceptance Laplacian of the network, with W = I. The window is Λ = {λ₂, λ₃}, the slowest inter-area modes. The stable mode is the spectral projector P_d onto that window.

**Formalism.** g is the separation of Λ from the rest of the spectrum. The noise envelope is ε₀ = g/40. The Davis–Kahan bound s(ε) = ε/(g − ε) gives s(ε₀) = 1/39. With ρ = 1/200, the tolerance is

  τ = s(ε₀) + ρ = **239/7800 ≈ 0.030641**.

**Replicas.** Five replicas isolate the stable mode from the same noisy state vector:

- R1 Jacobi;
- R2 Householder with implicit QL;
- R5 Lanczos with full reorthogonalisation;
- R3, with no eigensolver: the Newton matrix-sign function of (U·I − A)(A − L·I);
- R4, with no eigensolver: resolvent subspace iteration.

R1, R2 and R5 share one window-selection helper. That shared helper is the common-mode H1 fault.

**Auditor deviation.** dev(y, x) = ‖y − P_d x‖ / ‖x‖. The auditor makes one of three decisions:

- **Deliver certified** when the voted output has dev ≤ τ.
- **Select certified** otherwise: it tests each replica in order, delivers the first that passes, and records which replica it used and why the vote failed.
- **Refuse** when none passes: it keeps the last certified state and raises a topology-reprocessing alarm. It logs the deviation of every replica, the runtime topology hash and the certificate hash.

Each decision is appended to a hash-chained ledger in the browser.

**Live input.** The state vector is the DC power-flow solution of the system with every load and generator scaled by the live demand ratio. Grid takes that ratio from EIA-930 Lower-48 demand. If that feed is unavailable it uses the relay's ISO load ratio, and failing that a diurnal model. The ratio is clamped to 0.8–1.2, and the screen marks which source is in use with its evidence class. Operator EMS state vectors are not public, so the auditor runs on the public IEEE systems at the load level that today's U.S. demand sets.

## Certificates and pins

Each system ships a topology model and a certificate.

- **Exact branch.** The certificate gives an enclosure of Λ and of the gap. Those rest on inertia counts of A − σI at rational shifts σ, computed by exact sparse LDLᵀ over ℚ with a minimum-degree order.
- **Re-verification.** The browser recomputes these counts with BigInt rationals before the auditor starts:
  - IEEE 14: all of them.
  - IEEE 118: the critical ones. All 122 are one click away on the Formalism tab.
- **Tampering.** An altered certificate fails its pin and is refused.

| File | SHA-256 |
|---|---|
| `topology-ieee14.json` | `12a4c9838465b1808c2a06d02eee4970603ed99caae9250583ea8b8f6d7db775` |
| `certificate-ieee14.json` | `224054adeaa0600300b8141c435d04cbf2c9a22bee8cb91e1bdac2ad8ff0668e` |
| `topology-ieee118.json` | `10d06382a19d8dd252a9ca87a817ac1fafddb53960af928cdf5fd338c2b54e87` |
| `certificate-ieee118.json` | `6beaaab55f50acaa55bf7d49f44dbfc5ef765bbb98928ceddd1c745471d050a1` |

The pins live in `engine/pins.js`. They cover the certificate and the topology model used to build A. The **runtime** topology file is deliberately not pinned, as the specification requires. CM2 is exactly that case: one branch status in the shared runtime topology file flipped, which changes A for every replica at once.

## Acceptance — KKP-GRID-ACCEPTANCE-1.0

The same harness runs on both systems.

| | | |
|---|---|---|
| **Fault classes** | L0 (legitimate)<br>CM2 (one runtime topology entry altered)<br>H1 (shared helper defect)<br>E1 (envelope breach)<br>CM6 (spoofed input) | |
| **Trials** | 240 per class on IEEE 14<br>40 per class on IEEE 118 | |
| **Seed** | 47 | |
| **Harmful** | delivered y with ‖y − P_d x‖/‖x‖ > τ | |

**Harmful outputs passed** (CM2 + H1 + E1 + CM6):

| Pipeline | IEEE 14 | IEEE 118 |
|---|--:|--:|
| Voting (majority of 5 within τ) | 563 | 84 |
| Validated residual | 545 | 84 |
| Independent reference | 305 | 44 |
| Anomaly detector | 28 | 0 |
| **Certified auditor** | **240** (all CM6) | **40** (all CM6) |

**Auditor decisions and false alarms:**

| | IEEE 14 | IEEE 118 |
|---|--:|--:|
| Certified auditor, harmful passed outside CM6 | **0** | **0** |
| False alarms on legitimate trials: auditor | **0** of 240 | **0** of 40 |
| False alarms on legitimate trials: anomaly detector | 2 of 240 | 0 of 40 |
| Certified outputs delivered by auditor selection | 281 | 41 |
| Auditor refusals (last certified state kept, alarm raised) | 44 | 3 |
| Largest legitimate deviation vs tolerance | 0.0073 vs 0.0306 | 0.0010 vs 0.0306 |

Decision-log SHA-256:

- IEEE 14: `e498955c3c2a85a3ab6b28e4686323ffe4caab1f095d018bbbc2752449476841`
- IEEE 118: `56a55f3d9daf782946d6e0fff71272df30074b40468b7e9fc1201cd29fc35267`

The browser engine uses the same Mulberry32 and Box–Muller streams and the same per-trial seeds as the Python reference. `engine/monitor.test.mjs` asserts that the two agree decision by decision.

**Limits, as specified.** The auditor certifies the spectral component of the input it receives. Under CM6 the input itself is spoofed, so it passes all of them. Input integrity and certificate-pin integrity are separate controls. Grid shows the CM6 row rather than hiding it.

## E47 reference instantiation

The Formalism tab computes the E47 instantiation from scratch:

- H = V₂ ⊗ V₂ ⊗ V₂, of dimension 125;
- the spin-2 Casimir C and K = (C − 6I)(C − 30I), with dim ker K = 47;
- Γ = I − K²/99144, and the curve ‖Γⁿ − P‖ ≤ (15/17)ⁿ, attained at x*.

It checks the sector dimensions, tr P = 47 and the rate 15/17 against the City's `E47_LOCK`, imported live from `E47-Kartekeya/interfaces/shared/e47-lock.js`, with an embedded copy as fallback.

## Doorways

`tools/grid/install_door.py` surveys every published page across the nine Pages repositories:

- It places a **GRID** doorway on each page, as plain HTML that works with scripts off. A small script, `door.js`, moves the doorway clear of the page's own fixed panels and controls, including those inside same-origin embeds. It also shows the relay reading, and stays hidden inside iframes.
- It adds a lead card to the five hub pages.
- It writes the survey to `data/surfaces.json`. The Sources tab lists it in full: 184 site pages and one generator template. A page appears on the web whenever its repository's Pages site is switched on.

The installer is idempotent, so you can rerun it after adding pages.

## Reproduce

```bash
# data, certificates and pins (GPPD CSV, us-atlas states, gridstatus BA metadata as inputs)
python3 tools/grid/build_grid_data.py --gppd <gppd.csv> --atlas <states-10m.json> --ba <grid_monitor_files.json>

# Python reference acceptance run → grid/data/reference-acceptance.json
python3 tools/grid/acceptance.py --trials14 240 --trials118 40 --seed 47

# browser engine agrees with the reference, trial by trial
node --test grid/engine/monitor.test.mjs

# outlet meter on synthetic hum; edge-function parsers and request path on ERCOT, ODIN, emPOWER, NOAA, EPA ECHO and Drought Monitor fixtures
node grid/engine/enf.test.mjs

# disturbance detector: synthetic steps recover the swing equation; noise, ramps,
# gaps and malformed samples produce nothing; the panel always carries its limits
node --test grid/engine/disturbance.test.mjs
node tools/grid/test_grid_live.mjs

# mass-energy: stored vs flowing kept apart, units, and the panel's own wording
node --test grid/engine/massenergy.test.mjs

# water in the browser: service-area matching and ring orientation, the rounded EPA query, rivers near you, EPA standing
node tools/grid/test_grid_water.mjs

# alert service: encryption against http_ece, VAPID against an independent verifier, then end to end
npm install --prefix /tmp/wpt web-push@3.6.7 http_ece@1.2.0
node tools/grid/test_grid_alerts.mjs /tmp/wpt/node_modules

# flight: take-off height with terrain still loading, altitude hold, ▲ / ▼, hand flying, terrain floor
node tools/grid/test_grid_fly.mjs

# share card and cover art (headless Chrome)
python3 tools/grid/render_share_card.py --chrome /usr/bin/google-chrome

# doorways and lead cards across the sibling checkouts
python3 tools/grid/install_door.py --root <folder holding the repos> [--dry-run]

# one relay run by hand
pip install gridstatus==0.37.0 requests
EIA_API_KEY=... python3 tools/grid/relay.py --out out
```

## Layout

```
grid/
  index.html, app.js, grid.css     the instrument
  map/       map.js (scenes, layers, terminator, GPS), fly.js (flight model, HUD, line patrol)
  live/      sources.js (publishers, parsers, evidence classes), pulse.js (grid-live reads, interconnections),
             counties.js (county geometry and lookup), enf.js + enf-worklet.js (outlet frequency meter),
             alerts.js (background alerts, the medical-equipment plan), water.js (rivers, service areas, EPA standing)
  engine/    linalg, rational, certificate, monitor, e47, prng, worker, pins
  ui/        charts, panels, pages
  data/      topologies, certificates, CM2 surveys, plants, states, BA metadata, reference run, doorway survey
  lib/       MapLibre GL JS 6.19.0 (vendored)
  fonts/     Newsreader, IBM Plex Sans and Mono, DejaVu Sans Mono (formula glyphs), with licences
  sw.js, manifest.webmanifest, door.js, og-grid.png, cover-grid.jpg, icons/
tools/grid/supabase/grid-live/index.ts   the edge function for ERCOT, ODIN, HHS emPOWER, NOAA rivers, EPA ECHO water systems and drought
tools/grid/supabase/grid-alerts/         the alert service: index.ts (requests and the sweep), logic.ts (what is due), webpush.ts (RFC 8291 + VAPID)
tools/grid/supabase/migrations/          its two tables and the five-minute schedule
tools/grid/  build_grid_data.py, acceptance.py, prng.py, relay.py, render_share_card.py, share_card.html, install_door.py
.github/workflows/grid-live.yml
```

## Attribution

- Map rendering: MapLibre GL JS (BSD-3-Clause, `lib/maplibre/LICENSE.txt`).
- Imagery: © Esri, Maxar, Earthstar Geographics.
- Night lights and Day/Night Band: NASA GIBS / VIIRS.
- Terrain: AWS Open Data Terrain Tiles (SRTM, NED, GMTED), with JAXA AW3D30 as fallback.
- Transmission lines: HIFLD, via DOE NETL.
- Local grid: © OpenStreetMap contributors (ODbL).
- Plants: WRI Global Power Plant Database (CC BY 4.0), from EIA-860.
- Outages: ODIN, the Outage Data Initiative Nationwide (DOE / ORNL). Frequency: ERCOT.
- Counties: U.S. Census Bureau cartographic boundaries via us-atlas (ISC licence, `data/us-atlas-LICENSE.txt`). Places: © OpenStreetMap contributors via Nominatim.
- Public U.S. government data: NOAA SWPC, the National Weather Service, USGS, NIFC and EIA.
- Operator data: each ISO/RTO's public endpoints, through `gridstatus`.
- Test systems: MATPOWER / PYPOWER.
- Fonts: SIL Open Font License, and the DejaVu licence.
