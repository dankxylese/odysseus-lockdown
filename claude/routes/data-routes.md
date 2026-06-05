# Data Routes

Routes for user data: sessions, memory, notes, documents, gallery, vault.

## Memory Routes (routes/memory_routes.py)

```
GET    /api/memory              — list all memories (owner-filtered)
POST   /api/memory              — add memory {text, category}
PUT    /api/memory/{id}         — update memory
DELETE /api/memory/{id}         — delete memory
POST   /api/memory/search       — search {query}
POST   /api/memory/rebuild      — rebuild vector index from JSON store
```

## Skills Routes (routes/skills_routes.py)

```
GET    /api/skills              — list skills (owner-filtered)
POST   /api/skills              — create skill
PUT    /api/skills/{name}       — update skill
DELETE /api/skills/{name}       — delete skill
POST   /api/skills/{name}/publish — make skill public
GET    /api/skills/search?q=    — search skills
POST   /api/skills/audit        — run skill quality audit (admin)
```

Skills are stored as `SKILL.md` files on disk (not in DB). Format:
```markdown
# Skill Name
Description of what this skill does.
```

## Note Routes (routes/note_routes.py)

```
GET    /api/notes               — list notes/todos (owner-filtered)
POST   /api/notes               — create note {title, content, note_type, due_date}
GET    /api/notes/{id}          — get note
PUT    /api/notes/{id}          — update note
DELETE /api/notes/{id}          — delete note
POST   /api/notes/{id}/complete — mark checklist item complete
```

`note_type`: `"note"` | `"checklist"` | `"reminder"`
`due_date`: ISO8601 — triggers reminder notification

## Document Routes (routes/document_routes.py)

Editor canvas documents (not personal docs RAG):

```
GET    /api/documents           — list documents (owner-filtered)
POST   /api/documents           — create document {title, content, type}
GET    /api/documents/{id}      — get document + content
PUT    /api/documents/{id}      — update document
DELETE /api/documents/{id}      — delete document
GET    /api/documents/{id}/versions — version history
POST   /api/documents/{id}/restore/{version} — restore version
POST   /api/documents/import    — import from uploaded file
```

`type`: `"document"` | `"email"` | `"canvas"` | `"code"`

## Gallery Routes (routes/gallery_routes.py)

```
GET    /api/gallery             — list gallery images (owner-filtered)
POST   /api/gallery/import      — import generated image into gallery
DELETE /api/gallery/{id}        — delete image + file
POST   /api/gallery/{id}/sharpen — AI upscale/sharpen image (auth-checked)
GET    /api/generated-image/{filename} — serve image (in app.py directly)
```

Generated images go to `data/generated_images/<hash>.<ext>`. Gallery imports create a DB row linking the filename to the owner.

## Editor Draft Routes (routes/editor_draft_routes.py)

```
GET    /api/editor-drafts       — list saved image editor projects
POST   /api/editor-drafts       — save draft {name, state_json}
GET    /api/editor-drafts/{id}  — load draft
DELETE /api/editor-drafts/{id}  — delete draft
```

## Signature Routes (routes/signature_routes.py)

```
GET    /api/signatures          — list reusable image stamps
POST   /api/signatures          — create signature
DELETE /api/signatures/{id}     — delete
```

## Vault Routes (routes/vault_routes.py)

```
POST /api/vault/unlock          — unlock vault with master password
POST /api/vault/search          — search secrets {query}
GET  /api/vault/{key}           — retrieve secret by key
POST /api/vault               — store secret
DELETE /api/vault/{key}         — delete secret
```

All vault operations require vault to be unlocked (session-based unlock).

## Workspace Routes (routes/workspace_routes.py)

```
GET  /api/workspace             — list workspace files
POST /api/workspace/upload      — upload file to workspace
DELETE /api/workspace/{path}    — delete workspace file
```
