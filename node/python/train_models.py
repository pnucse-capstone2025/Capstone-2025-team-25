import json
import torch
from datasets import load_dataset
from transformers import (
    AutoTokenizer,
    AutoModelForSequenceClassification,
    AutoModelForSeq2SeqLM,
    DataCollatorWithPadding,
    DataCollatorForSeq2Seq,
    TrainingArguments,
    Trainer
)

CLASSIFIER_MODEL_NAME = "klue/roberta-base"
GENERATOR_MODEL_NAME = "google/mt5-small"
CLASSIFIER_OUTPUT_DIR = "./prescription_classifier"
GENERATOR_OUTPUT_DIR = "./prescription_generator"

def train_classifier():
    print("STARTING CLASSIFIER TRAINING")


    dataset = load_dataset('csv', data_files='classifier_dataset.csv')['train'].train_test_split(test_size=0.1)
    with open('classifier_labels.json', 'r', encoding='utf-8') as f:
        labels_map = json.load(f)
        id2label = labels_map['id2label']
        label2id = labels_map['label2id']

    tokenizer = AutoTokenizer.from_pretrained(CLASSIFIER_MODEL_NAME)

    def preprocess_function(examples):
        return tokenizer(examples["text"], truncation=True, max_length=128)

    tokenized_dataset = dataset.map(preprocess_function, batched=True)
    data_collator = DataCollatorWithPadding(tokenizer=tokenizer)

    model = AutoModelForSequenceClassification.from_pretrained(
        CLASSIFIER_MODEL_NAME, num_labels=len(id2label), id2label=id2label, label2id=label2id
    )

    training_args = TrainingArguments(
        output_dir=CLASSIFIER_OUTPUT_DIR,
        learning_rate=2e-5,
        per_device_train_batch_size=16,
        per_device_eval_batch_size=16,
        num_train_epochs=5,
        weight_decay=0.01,
        evaluation_strategy="epoch",
        save_strategy="epoch",
        load_best_model_at_end=True,
    )

    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=tokenized_dataset["train"],
        eval_dataset=tokenized_dataset["test"],
        tokenizer=tokenizer,
        data_collator=data_collator,
    )

    print("\n--- Fine-tuning KLUE/RoBERTa Classifier ---")
    trainer.train()

    print(f"\n--- Saving classifier model to '{CLASSIFIER_OUTPUT_DIR}' ---")
    trainer.save_model(CLASSIFIER_OUTPUT_DIR)
    print("✅ Classifier training complete!")

def train_generator():
    print("STARTING GENERATOR TRAINING")
    
    dataset = load_dataset('csv', data_files='generator_dataset.csv')['train'].train_test_split(test_size=0.1)
    tokenizer = AutoTokenizer.from_pretrained(GENERATOR_MODEL_NAME)
    prefix = "translate Korean to JSON: "

    def preprocess_function(examples):
        inputs = [prefix + doc for doc in examples["input_text"]]
        model_inputs = tokenizer(inputs, max_length=128, truncation=True)
        with tokenizer.as_target_tokenizer():
            labels = tokenizer(examples["target_text"], max_length=128, truncation=True)
        model_inputs["labels"] = labels["input_ids"]
        return model_inputs

    tokenized_dataset = dataset.map(preprocess_function, batched=True)
    model = AutoModelForSeq2SeqLM.from_pretrained(GENERATOR_MODEL_NAME)
    data_collator = DataCollatorForSeq2Seq(tokenizer=tokenizer, model=model)

    training_args = TrainingArguments(
        output_dir=GENERATOR_OUTPUT_DIR,
        evaluation_strategy="epoch",
        learning_rate=2e-5,
        per_device_train_batch_size=16,
        per_device_eval_batch_size=16,
        weight_decay=0.01,
        save_total_limit=3,
        num_train_epochs=5,
        predict_with_generate=True,
    )

    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=tokenized_dataset["train"],
        eval_dataset=tokenized_dataset["test"],
        tokenizer=tokenizer,
        data_collator=data_collator,
    )

    print("\n--- Fine-tuning mT5-small Generator ---")
    trainer.train()

    print(f"\n--- Saving generator model to '{GENERATOR_OUTPUT_DIR}' ---")
    trainer.save_model(GENERATOR_OUTPUT_DIR)
    print("✅ Generator training complete!")

if __name__ == '__main__':
    if torch.cuda.is_available():
        print(f"GPU detected: {torch.cuda.get_device_name(0)}. Using GPU for training.")
    else:
        print("Warning: No GPU detected. Training will be very slow on CPU.")
    train_classifier()
    train_generator()
