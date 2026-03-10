---
name: odoo-gen:extend
description: Fork and extend an existing Odoo module with a companion _ext module
argument-hint: "<module_name> --repo <oca_repo>"
---
<objective>
Clone an existing OCA module and generate a companion extension module ({module}_ext) that adds your custom functionality without modifying the original. Uses Odoo _inherit and xpath patterns for clean extensibility.

Typically invoked after `/odoo-gen:search` identifies a matching module. Can also be used directly with a known module name and OCA repo.
</objective>

<execution_context>
@~/.claude/odoo-gen/agents/odoo-extend.md
</execution_context>
