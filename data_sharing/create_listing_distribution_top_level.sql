CREATE OR REPLACE LISTING EV_GOLD_LISTING
  FOR SHARE EV_GOLD_SHARE
  DISTRIBUTION = 'PRIVATE'
  AS
  $$
  title: "WA Electric Vehicle Registration Analytics"
  subtitle: "Gold-layer aggregates for EV adoption insights"
  description: "Curated aggregates from the Washington State DOL EV Registration dataset. Includes registrations by year/make, adoption by county, and BEV vs PHEV share."
  terms_of_service:
    type: "OFFLINE"
  targets:
    accounts: ["ORG1.PARTNER_ACCOUNT"]
  $$