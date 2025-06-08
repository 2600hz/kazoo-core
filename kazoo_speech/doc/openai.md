# OpenAI Text-to-Speech API

## Configuration

Set the TTS provider setting to OpenAI:

```shell
sup kapps_config set_default speech tts_provider openai
```

Then configure the OpenAI TTS settings:

```shell
sup kapps_config set_default speech.openai {KEY} {VALUE}
```

| Key           | Value                                                           |
| ---           | -----                                                           |
| `tts_api_key` | "Your-API-Key"                                                  |
| `tts_url`     | https://api.openai.com/v1/audio/speech                          |
| `tts_model`   | tts-1-hd | tts-1-hd-1106 | tts-1 | tts-1-1106 | gpt-4o-mini-tts |
| `tts_speed`   | 1.0                                                             |

## Available voices

* male
* female

## Available languages

* en-us
* en-gb
