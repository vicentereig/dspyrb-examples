# Attribution

These fixtures are derived from the [ubicloud/llm-changelog-generator](https://github.com/ubicloud/llm-changelog-generator) repository.

## Original Work

- **Organization**: Ubicloud
- **Repository**: [llm-changelog-generator](https://github.com/ubicloud/llm-changelog-generator)
- **License**: Check the original repository for license information
- **Purpose**: LLM-generated changelogs from GitHub pull requests

## Files Included

### Prompts (fixtures/llm-changelog-generator/prompts/)
- `claude-opus-4-prompt.txt` - Claude Opus 4 model prompt
- `claude-opus-4-tweak-prompt.txt` - Tweaked Claude Opus 4 prompt
- `claude-opus-4-tweak-feb-prompt.txt` - February-specific tweaked prompt
- `openai-4o-prompt.txt` - OpenAI 4o model prompt
- `openai-o3-prompt.txt` - OpenAI o3 model prompt
- `openai-o4-mini-high-prompt.txt` - OpenAI o4-mini-high model prompt
- `prompt-generating-prompt.txt` - Meta-prompt for generating changelog prompts

### Data (fixtures/llm-changelog-generator/data/)
- `feb-pull-requests.json` - February 2025 pull request data
- `may-pull-requests.json` - May 2025 pull request data

## Usage

These fixtures are used for educational and research purposes to demonstrate the implementation of a modular changelog generator using DSPy.rb, comparing it against the original monolithic prompt approach.

All credit for the original implementation and prompts goes to the Ubicloud team.