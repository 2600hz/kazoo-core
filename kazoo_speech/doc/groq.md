# Groq Text-to-Speech API

## Configuration

Set the TTS provider setting to Groq:

```shell
sup kapps_config set_default speech tts_provider groq
```

Then configure the Groq TTS settings:

```shell
sup kapps_config set_default speech.groq {KEY} {VALUE}
```

| Key           | Value                                                           |
| ---           | -----                                                           |
| `tts_api_key` | "Your-API-Key"                                                  |
| `tts_url`     | https://api.groq.com/openai/v1/audio/speech                     |
| `tts_model`   | playai-tts                                                      |

## Available voices

* male
* female

## Available languages

* en-us
* en-gb

# Groq Cloud Speech API

## Configuration

Set the ASR provider setting to openai:
its not a document error, use openai as provider for groq

```shell
sup kapps_config set_default speech asr_provider openai
```
Then configure the Groq specific ASR settings:

```shell
sup kapps_config set_default speech.openai {KEY} {VALUE}
```

| Key                                   | Value                                             |
| ---                                   | -----                                             |
| `asr_api_key`                         | "Your-API-Key"                                    |
| `asr_url`                             | https://api.groq.com/openai/v1/audio/transcriptions |
| `asr_model`                           | `whisper-large-v3-turbo` | `distil-whisper-large-v3-en` | `whisper-large-v3` |

OpenAI ASR can support any other open-source or commercial apis based on openai
