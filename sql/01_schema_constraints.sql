USE saas_churn_analytics;

-- 1. Convert ID columns from generic TEXT to indexed VARCHAR(50)
ALTER TABLE accounts MODIFY account_id VARCHAR(50) NOT NULL;
ALTER TABLE subscriptions MODIFY subscription_id VARCHAR(50) NOT NULL, MODIFY account_id VARCHAR(50) NOT NULL;
ALTER TABLE feature_usage MODIFY usage_id VARCHAR(50) NOT NULL, MODIFY subscription_id VARCHAR(50) NOT NULL;
ALTER TABLE support_tickets MODIFY ticket_id VARCHAR(50) NOT NULL, MODIFY account_id VARCHAR(50) NOT NULL;
ALTER TABLE churn_events MODIFY churn_event_id VARCHAR(50) NOT NULL, MODIFY account_id VARCHAR(50) NOT NULL;

-- 2. Add Primary Keys
ALTER TABLE accounts ADD PRIMARY KEY (account_id);
ALTER TABLE subscriptions ADD PRIMARY KEY (subscription_id);
ALTER TABLE feature_usage ADD PRIMARY KEY (usage_id);
ALTER TABLE support_tickets ADD PRIMARY KEY (ticket_id);
ALTER TABLE churn_events ADD PRIMARY KEY (churn_event_id);

-- 3. Add Foreign Keys
ALTER TABLE subscriptions ADD CONSTRAINT fk_subs_account FOREIGN KEY (account_id) REFERENCES accounts(account_id);
ALTER TABLE feature_usage ADD CONSTRAINT fk_usage_sub FOREIGN KEY (subscription_id) REFERENCES subscriptions(subscription_id);
ALTER TABLE support_tickets ADD CONSTRAINT fk_tickets_account FOREIGN KEY (account_id) REFERENCES accounts(account_id);
ALTER TABLE churn_events ADD CONSTRAINT fk_churn_account FOREIGN KEY (account_id) REFERENCES accounts(account_id);

-- 4. Visually inspect subscriptions & feature_usage columns before building our Master View
DESCRIBE subscriptions;
DESCRIBE feature_usage;