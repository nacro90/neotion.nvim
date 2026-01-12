---
description: Start implementing a TODO with TDD approach
allowed-tools: mcp, Bash, Read, Write, Edit, MultiEdit, Grep, Glob, TodoRead, TodoWrite, AskUserQuestion, Task
---

# Start TODO: $ARGUMENTS

## 1. Find the TODO

First, locate the TODO by ID:

```bash
grep -rn "TODO(neotion:$ARGUMENTS" --include="*.lua" lua/
```

If no ID provided or not found, list all TODOs and ask user to select:
```bash
grep -rn "TODO(neotion:" --include="*.lua" lua/
```

## 2. Parse TODO Details

Extract from the TODO comment:
- **ID**: The TODO identifier (e.g., FEAT-12.1, 11.3)
- **Priority**: CRITICAL, HIGH, MEDIUM, LOW
- **Description**: Main task description
- **Details**: Any additional comment lines below

## 3. Pre-Implementation

1. **Serena Activate**: Activate Serena for semantic code operations
2. **Context Gathering**: Read related code to understand the scope
3. **Agent Consultation**: If needed, consult architect-agent and ux-designer for design decisions

## 4. Implementation Plan

Present to user:
- What will be implemented
- Which files will be affected
- Test strategy (unit tests, integration tests)
- Expected outcomes

**Ask for approval before proceeding.**

## 5. TDD Workflow

```
[Understand TODO] → [Plan + User Approval] → [Write Tests] → [Implement] → [Run Tests] → [Code Review] → [User Verification] → [Remove TODO] → [Commit]
```

### Guidelines

- **Test-Driven**: Write tests first when possible
- **Interactive**: Use AskUserQuestion at decision points
- **Incremental**: Show progress at each stage

### Decision Points (Always Ask!)

| Situation | Action |
|-----------|--------|
| Multiple solutions | Present options with trade-offs |
| Scope expansion | Ask if should be separate TODO |
| Breaking change | Get explicit approval |
| UX decisions | Present alternatives |

## 6. Completion

When implementation is done:

1. **Run all tests**: `make test`
2. **Code review**: Use code-reviewer agent
3. **User verification**: Let user test manually
4. **Remove TODO**: Delete the TODO comment from code
5. **Commit**: With conventional commit format

```bash
# Example commit
git commit -m "feat(render): improve header visual appearance (FEAT-12.1)"
```

## Important Rules

- Be interactive - don't make decisions alone
- Report progress at each stage
- Share test results
- Ask before committing
- Remove TODO comment after successful implementation
