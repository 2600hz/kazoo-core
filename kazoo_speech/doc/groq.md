# Groq Text-to-Speech API

## Configuration

Set the TTS provider setting to Groq:

```shell
sup kapps_config set_default speech tts_provider groq
```

Then configure the OpenAI TTS settings:

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
