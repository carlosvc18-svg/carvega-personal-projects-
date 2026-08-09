-- Target specific consumer accounts
ALTER LISTING EV_GOLD_LISTING SET
  TARGETS = '{"accounts": ["ORG1.PARTNER_ACCT", "ORG2.ANALYTICS_ACCT"]}';

-- Publish when ready
ALTER LISTING EV_GOLD_LISTING SET PUBLISH = TRUE;