CREATE LISTING EV_GOLD_LISTING
  FOR SHARE EV_GOLD_SHARE
  AS
  $$
  title: "WA Electric Vehicle Registration Analytics"
  subtitle: "Gold-layer aggregates: adoption by county, BEV/PHEV share, registrations by year/make"
  description: |
    Curated aggregates from the Washington State DOL Electric Vehicle Registration dataset.
    Includes:
    - Registrations by model year and manufacturer
    - EV adoption ranking by county
    - BEV vs PHEV market share by county
    Updated daily via automated pipeline.
  terms_of_service:
    type: "OFFLINE"
  distribution: "INTERNAL"
  targets:
    accounts: ["ORG1.PARTNER_ACCOUNT"]
  $$