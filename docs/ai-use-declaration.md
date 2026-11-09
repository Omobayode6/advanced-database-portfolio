# AI-use declaration

**Tool:** Cursor, using the Grok model.

**What it was used for:** I used it in drafting the CartIt PostgreSQL schema, seed data, queries, transaction function, concurrency script, and MongoDB catalog script.

**What I checked myself:**

- [x] I created the git up repository, committed and pushed it.
- [x] I created the supabase project and run queries to confirm the created tables and many others
- [x] I ran `npm run db:schema` and `npm run db:seed` against my own Supabase project and saw the `cartit` tables.
- [x] I ran the business queries and the two `EXPLAIN` plans and filled `analysis.md` from my output, not from memory.
- [x] I ran `npm run db:transactions` and `npm run concurrency` and can point to the committed backpack sale, the rolled-back mug sale, and the last-sneaker race in the evidence files.
- [x] I ran `npm run nosql` which returned CartIt Laptop Pro.
- [x] I rewrote the reflection after those runs.
- [x] I can explain, without reading the files line by line, why the order line stores a price and why checkout locks `stock_levels`.

**Result:** I remain responsible for the accuracy of the submission. Where a script result disagreed with a comment, I treated the result as the evidence and corrected the note.
