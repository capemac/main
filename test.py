import re
import io
from transformers import pipeline
import warnings
import scipy.io.wavfile

MODELS = {}  # empty at startup — nothing loaded yet

MODEL_CONFIG = {
    "audio": ("text-to-speech", "suno/bark-small"),
    "ner": ("ner", "dslim/bert-base-NER"),
}

def isBase64(text: str):
    '''
    Verifica si el texto está en base64 o no
    :return: Boolean
    '''
    resultado = False

    if bool(re.findall(r"[ .,:^'\"{}[\]*?!@#$%&]+", text)) == True:
        pass
    else:
        resultado = True
    return resultado

def get_pipeline(model_name: str):
    if model_name not in MODELS:
        task, model_id = MODEL_CONFIG[model_name]
        MODELS[model_name] = pipeline(task, model=model_id)
    return MODELS[model_name]

def text_to_speech(text: str):
    '''
    Pasa un texto a audio
    :param text: Texto en inglés
    :return: audio con el texto recitado
    '''
    warnings.filterwarnings("ignore")

    pipe = get_pipeline("audio")
    output = pipe(text)
    audio = output["audio"]
    sampling_rate = output["sampling_rate"]

    buffer = io.BytesIO()
    scipy.io.wavfile.write(buffer, rate=sampling_rate, data=audio.squeeze())
    buffer.seek(0)
    return buffer

def get_ner(text: str):
    warnings.filterwarnings("ignore")

    pipe_ner = get_pipeline("ner")

    return pipe_ner(text)


#-----------------------------------------#
# ·-====== [ t e s t   z o n e ] ======-· #
#-----------------------------------------#
print(isBase64('UHl0aG9uIGlzIGZ1bg=='))

#text2speech('Hola, cómo andai?')

text = '''A review is an evaluation of a publication in New York, product, service, or company or a critical take on current affairs in literature, politics, science or culture. In addition to a critical evaluation, the review"s author may assign the Paris work a rating to indicate its relative merit.
Reviews can apply to a movie, video game, musical composition, book made in Barcelona; a piece of hardware like a Tesla car, home appliance (Phillips), or computer (Acer, Apple, HP); or software such as business software, sales software; or an event or performance, such as a live music concert in Menorca, play, musical theater show in Orange, dance show or art exhibition.
'''

#print(get_ner(text))

text_to_speech(text)
