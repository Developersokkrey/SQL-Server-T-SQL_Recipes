#001 --------------------------------- UNIQUE KEY CONSTRAINT --------------------------------------
     ALTER TABLE YourTable ADD CONSTRAINT UQ_UserId_ContactID UNIQUE(UserId, ContactID)
