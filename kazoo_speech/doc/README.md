# kazoo Speech

This core library governs integrations with [Text-to-Speech (TTS) providers](https://en.wikipedia.org/wiki/Speech_synthesis) and with (Automatic Speech Recognition (ASR) engines)[https://en.wikipedia.org/wiki/Speech_recognition] to allow Kazoo callflows to take advantage of the advanced functionality these provide.

## TTS

Kazoo, by default, will use the internal [mod_flite](https://freeswitch.org/confluence/display/FREESWITCH/mod_flite) to play the text from a [TTS callflow action](../../../applications/callflow/doc/tts.md).

There are also modules for
[iSpeech](http://www.ispeech.org/api/#text-to-speech)
[VoiceFabric](https://voicefabric.ru/user_documentation)
[Google](https://cloud.google.com/text-to-speech)
[OpenAI](https://platform.openai.com/docs/guides/text-to-speech)
[Groq](https://console.groq.com/docs/text-to-speech)
[Deepgram](https://deepgram.com/product/text-to-speech)

## ASR

Kazoo currently supports as an ASR engine:

1. [iSpeech](http://www.ispeech.org/api/#automated-speech-recognition)
2. [Google Cloud Speech API](https://cloud.google.com/speech/)
3. [IBM Watson](https://www.ibm.com/products/speech-to-text)
4. [OpenAI](https://platform.openai.com/docs/guides/speech-to-text)
5. [Groq](https://console.groq.com/docs/speech-to-text)

### Service Plan Definitions
1. The ASR block defines usage rates for the providers
2. The transcription block defines rates for having transcribe enabled on a vmbox
```
"asr": {
       "google": {
           "rate": 1,
           "name": "Google ASR"
       },
       "ispeech": {
           "rate": 1,
           "name": "ispeech ASR"
       }
   },
   "plan": {
   ....
       "voicemails": {
           "mailbox": {
               "name": "Voicemail Box",
               "rate": 1.99,
               "cascade": true
           },
           "transcription": {
               "cascade": true,
               "rate": 1,
               "name": "VMBox Transcription MRC"
           }
       },
....
```
