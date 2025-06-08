# Deepgram Text-to-Speech API

## Configuration

Set the TTS provider setting to Deepgram:

```shell
sup kapps_config set_default speech tts_provider deepgram
```

Then configure the OpenAI TTS settings:

```shell
sup kapps_config set_default speech.deepgram {KEY} {VALUE}
```

| Key           | Value                                                           |
| ---           | -----                                                           |
| `tts_api_key` | "Your-API-Key"                                                  |
| `tts_url`     | https://api.deepgram.com/v1/speak                               |

## Available voices

* male
* female

## Available languages

* en-us
* en-gb
