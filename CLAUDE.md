# Claude Development Instructions

## TDD Workflow Requirements

### Core Principles
- **Work using Test-Driven Development (TDD) style**
- **Always track progress in a GitHub Issue**
- **Test a little, code a little**
- **Commit often with clear messages**

### Development Cycle

1. **Red Phase**: Write a failing test first
2. **Green Phase**: Write minimal code to make test pass
3. **Refactor Phase**: Improve code while keeping tests green
4. **Document**: Post concise summary to issue when tests are green

### Issue Tracking Protocol

For each development phase:
1. Comment on the issue with current phase starting
2. Show test being written (Red)
3. Show implementation (Green)
4. Post summary when phase complete with:
   - What was tested
   - What was implemented
   - Test results (should be green ✅)
   - Next phase planned

### Commit Strategy
- Commit after each test passes
- Use descriptive commit messages:
  - `test: add failing test for [feature]`
  - `feat: implement [feature] to pass test`
  - `refactor: improve [feature] implementation`
  - `docs: update issue with phase summary`

### Example Workflow

```ruby
# 1. Write failing test
# Commit: "test: add failing test for ADE status enum"

# 2. Run test - see it fail (Red)
# Post to issue: "Starting Phase 1.1: ADE Status Enum - Test written ❌"

# 3. Implement minimal code
# Commit: "feat: implement ADEStatus enum to pass test"

# 4. Run test - see it pass (Green)
# Post to issue: "Phase 1.1 Complete ✅: ADEStatus enum with 3 values implemented"

# 5. Refactor if needed
# Commit: "refactor: extract enum values to constants"

# 6. Move to next test
```

### Testing Best Practices
- Each test should be independent
- Use VCR for all external API calls
- Keep tests focused and fast
- Test behavior, not implementation
- Aim for >90% test coverage

### Issue Comment Template

```markdown
## Phase X.Y: [Feature Name]

**Status**: ✅ Complete

**Tests Written**:
- Test description 1
- Test description 2

**Implementation**:
- What was built to pass tests

**Results**:
```
rspec spec/path/to/test.rb
...... (6 examples, 0 failures)
```

**Next**: Phase X.Z - [Next Feature]
```

### Remember
- Never implement without a test
- Keep cycles small (15-30 min)
- Post updates frequently to issue
- Commit working code often
- If stuck, write a simpler test