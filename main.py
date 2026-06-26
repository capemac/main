import re
import base64
import io
from transformers import pipeline
import warnings
import scipy.io.wavfile
from fastapi import FastAPI
from fastapi.responses import StreamingResponse
import gradio as gr

app = FastAPI()

MODELS = {}  # empty at startup — nothing loaded yet

MODEL_CONFIG = {
    "audio": ("text-to-speech", "suno/bark-small"),
    "ner": ("ner", "dslim/bert-base-NER"),
    "sentiment": ("sentiment-analysis", "distilbert-base-uncased-finetuned-sst-2-english"),
}

@app.get('/sentiment')
def get_sentiment(text: str):
    '''
    Análisis de sentimiento
    :param text: texto
    :return: Puntuación
    '''
    pipe = get_pipeline("sentiment")

    result = pipe(text)
    return [{**r, "score": float(r["score"])} for r in result]


@app.get('/codeBase64')
def codeBase64(text:str):
    '''
    Codifica/Decodifica el texto en base64
    :param text: texto plano o texto en base64
    :return: lo contrario que la entrada
    '''
    result = None
    if isBase64(text):
        result = {"result": base64.b64decode(text).decode("utf-8")}
    else:
        result = {"result": base64.b64encode(text.encode("utf-8")).decode("utf-8")}

    return result

def isBase64(text:str) -> bool:
    '''
    Verifica si el texto está en base64 o no
    :return: Boolean
    '''
    resultado = False

    if bool(re.findall(r"[ .,:^'\"{}[\]*?!@#$%&]+", text)) == True:
        resultado = False
    else:
        resultado = True
    return resultado

@app.get('/text_transform')
def text_transform(text: str, type: str):
    """
    Convierte texto a mayúsculas o minúsculas
    :param text: Cadena a convertir
    :param type: U-Mayúsculas, L-minúsculas, C-capital
    :return: texto convertido
    """

    retorno = str()
    match type.upper()[0]:
        case "U":
            retorno = text.upper()
        case "L":
            retorno = text.lower()
        case "C":
            retorno = text.capitalize()
        case "T":
            retorno = text.title()
        case _:
            retorno = ''
            raise ValueError("Opción no permitida -> (U/L/C)")

    return retorno

def get_pipeline(model_name: str):
    '''
    Devuelve la instancia de pipeline del modelo pasado por parámetro.
    Permite "lazy loading" para cargar el modelo una sola vez
    :param model_name:
    :return: path modelo
    '''
    if model_name not in MODELS:
        task, model_id = MODEL_CONFIG[model_name]
        MODELS[model_name] = pipeline(task, model=model_id)
    return MODELS[model_name]

@app.get('/text_to_audio')
def text_to_audio(text: str):
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

    return StreamingResponse(buffer, media_type="audio/wav")

@app.get('/ner')
def get_ner(text: str):
    warnings.filterwarnings("ignore")

    pipe_ner = get_pipeline("ner")

    return pipe_ner(text, aggregation_strategy="simple")

#===========================================================#
#       ------------ [Gradio front-end] ------------        #
#===========================================================#

def gradio_sentiment(text):
    pipe = get_pipeline("sentiment")
    output = pipe(text)
    return [{**r, "score": float(r["score"])} for r in output]

def gradio_speak(text):
    pipe = get_pipeline("audio")
    output = pipe(text)
    return output["sampling_rate"], output["audio"].squeeze()

def gradio_ner(text):
    pipe = get_pipeline("ner")
    entities = pipe(text, aggregation_strategy="simple")
    return {"entities": [{**e, "score": float(e["score"])} for e in entities]}

def gradio_base64(text):
    return codeBase64(text)

def gradio_text_transform(text, type_):
    return text_transform(text, type_)

demo = gr.TabbedInterface(
    [
        gr.Interface(fn=gradio_speak, inputs="text", outputs="audio", title="Text to Speech"),
        gr.Interface(fn=gradio_ner, inputs="text", outputs="json", title="NER"),
        gr.Interface(fn=gradio_base64, inputs="text", outputs="json", title="Base64"),
        gr.Interface(
            fn=gradio_text_transform,
            inputs=["text", gr.Dropdown(choices=[("Mayúsculas", "U"), ("Minúsculas", "L"), ("Capital", "C"), ("Título", "T")], label="Type", value="U")],
            outputs="text",
            title="Text Transform",
        ),
gr.Interface(fn=gradio_sentiment, inputs="text", outputs="json", title="Sentiment"),
    ],
    tab_names=["Speak", "NER", "Base64", "Text Transform", "Sentiment analysis"],
)

# Start the app: uvicorn main:app --reload
# Gradio interface http://127.0.0.1:8000/ui
# FastAPI interface http://127.0.0.1:8000/docs
app = gr.mount_gradio_app(app, demo, path="/ui")
