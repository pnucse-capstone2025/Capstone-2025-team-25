import base64
import json
import os
import re
import pandas as pd
import google.generativeai as genai
from rapidfuzz import process, fuzz
import sys
from dotenv import load_dotenv 

load_dotenv() 
script_dir = os.path.dirname(os.path.abspath(__file__))
csv_path = os.path.join(script_dir, "medicines.csv")

print(f"[Python] Received arguments: {sys.argv}", file=sys.stderr)

try:
    med_dict = pd.read_csv(csv_path)
    if 'id' not in med_dict.columns:
        raise ValueError("The 'medicines.csv' file must contain an 'id' column.")
except Exception as e:
    error_msg = {"error": f"Failed to load medicines.csv: {e}"}
    print(json.dumps(error_msg), file=sys.stderr)
    sys.exit(1)

try:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY not found in .env file or environment variables.")
    genai.configure(api_key=api_key)
except Exception as e:
    error_msg = {"error": f"Failed to configure Gemini client: {e}"}
    print(json.dumps(error_msg), file=sys.stderr)
    sys.exit(1)

def extract_prescription(filepath: str):
    """
    Encodes an image, sends it to Gemini 1.5 Flash, and asks for structured
    JSON output including a confidence score.
    """
    try:
        with open(filepath, "rb") as image_file:
            image_part = {
                "mime_type": "image/jpeg", 
                "data": base64.b64encode(image_file.read()).decode()
            }
    except FileNotFoundError:
        return {"error": "Image file not found."}
    except Exception as e:
        return {"error": f"Could not read or encode image: {e}"}
        
    model = genai.GenerativeModel('gemini-2.0-flash')

    prompt = """
    You are a highly accurate prescription OCR (Optical Character Recognition) system.
    Analyze the provided image of a medical prescription.
    Extract the patient's name and a list of all medications.
    For each medication, extract its name, dosage, frequency per day, duration in days, and any specific instructions.
    
    CRITICAL: Provide an overall 'extractionConfidence' score between 0.0 and 1.0, representing your confidence in the accuracy of the entire extraction.
    
    Return the result ONLY as a single, well-formed JSON object matching this exact structure:
    
    {
      "extractionConfidence": <float, 0.0 to 1.0>,
      "patient": {
        "name": "<string>"
      },
      "medications": [
        {
          "name": "<string>",
          "dosage": <number, e.g., 1 or 0.5>,
          "frequency": <integer, times per day>,
          "duration": <integer, in days>,
          "instructions": "<string>"
        }
      ]
    }
    """

    try:
        response = model.generate_content(
            [prompt, image_part],
            generation_config={"response_mime_type": "application/json"}
        )
        data = json.loads(response.text)
        print("\n[Python] Raw Gemini Extraction:", json.dumps(data, indent=2, ensure_ascii=False), file=sys.stderr)
        return data
    except Exception as e:
        error_msg = {"error": f"An error occurred during Gemini API extraction: {str(e)}"}
        print(json.dumps(error_msg), file=sys.stderr)
        return {"medications": [], "extractionConfidence": 0.0}


def normalize_med_name(ocr_name: str, med_dict_df: pd.DataFrame):
    if med_dict_df.empty or not ocr_name:
        return {"name": ocr_name, "id": -1}
    cleaned_name = re.sub(r'\s*\d+(\.\d+)?\s*(mg|mL|g|IU)|\s*\(P/PP\)|\s*\(\d+\)', '', ocr_name, flags=re.IGNORECASE).strip()
    name_kr_list = med_dict_df["NameKr"].dropna().tolist()
    result = process.extractOne(cleaned_name, name_kr_list, scorer=fuzz.WRatio, score_cutoff=75)
    if result:
        match, _, _ = result
        row = med_dict_df.loc[med_dict_df["NameKr"] == match].iloc[0]
        return {"name": match, "id": int(row["id"])}
    return {"name": cleaned_name, "id": -1}

def parse_instruction(instruction_text: str):
    if re.search(r'(취침|자기)\s*전', instruction_text, re.IGNORECASE):
        return {"scheduleType": "bedtime"}
    time_pattern = re.compile(r'(\d{1,2})\s*(?:시|:|am|pm)', re.IGNORECASE)
    found_times = time_pattern.findall(instruction_text)
    if found_times:
        strict_times = []
        for time_str in found_times:
            hour = int(time_str)
            if 'pm' in instruction_text.lower() and 1 <= hour < 12: hour += 12
            elif 'am' in instruction_text.lower() and hour == 12: hour = 0
            strict_times.append(f"{hour:02d}:00:00")
        if strict_times:
            return {"scheduleType": "nTimes", "isNTimesStrict": True, "nTimesCount": len(strict_times), "strictTimes": sorted(list(set(strict_times)))}
    interval_match = re.search(r'(\d{1,2})\s*시간\s*(?:마다|간격)', instruction_text, re.IGNORECASE)
    if interval_match:
        hours = int(interval_match.group(1))
        return {"scheduleType": "interval", "intervalHours": hours}
    ntimes_match = re.search(r'(?:하루|1일|매일)\s*(\d{1,2})\s*(?:회|번)', instruction_text, re.IGNORECASE)
    if ntimes_match:
        count = int(ntimes_match.group(1))
        return {"scheduleType": "nTimes", "isNTimesStrict": False, "nTimesCount": count}
    meal_keywords = {"아침": "breakfast", "점심": "lunch", "저녁": "dinner"}
    relation_keywords = {"식후": "after", "식전": "before"}
    relation, meals = None, []
    for keyword, value in relation_keywords.items():
        if keyword in instruction_text: relation = value; break
    for keyword, value in meal_keywords.items():
        if keyword in instruction_text: meals.append(value)
    if meals or relation or "식사" in instruction_text:
        if not meals and "식사" in instruction_text: meals = ["breakfast", "lunch", "dinner"]
        if meals and not relation: relation = "after"
        return {"scheduleType": "mealBased", "mealRelation": relation, "selectedMeals": sorted(list(set(meals)))}
    return { "scheduleType": "once" }

def prescription_pipeline(image_path: str, med_dict_df: pd.DataFrame) -> dict:
    CONFIDENCE_THRESHOLD = 0.4  # Set your desired confidence level here

    if not os.path.exists(image_path):
        return {"error": f"Image file not found at path: {image_path}"}
    
    extracted_data = extract_prescription(image_path)

    confidence = extracted_data.get("extractionConfidence", 0.0)
    if confidence < CONFIDENCE_THRESHOLD:
        error_message = f"Extraction confidence ({confidence:.2f}) is below the required threshold of {CONFIDENCE_THRESHOLD}. Please use a clearer image."
        return {"error": error_message}
    
    medications = extracted_data.get("medications")
    if not medications:
        return {"error": "Gemini extracted the data with sufficient confidence but found no medications."}
         
    parsed_tasks = []
    for med in medications:
        ocr_name = med.get("name") or "Unknown Medication"
        
        normalized_info = normalize_med_name(ocr_name, med_dict_df)
        instruction_details = parse_instruction(med.get("instructions", ""))
        
        task_state = {
            "isMedication": True,
            "medicationName": normalized_info["name"],
            "medicationId": normalized_info["id"],
            "description": f"Dosage: {med.get('dosage')}, Instructions: {med.get('instructions', 'N/A')}",
            "startDate": pd.Timestamp.now().strftime('%Y-%m-%d'),
            "duration": str(med.get("duration", "")),
            **instruction_details 
        }
        parsed_tasks.append(task_state)

    return {"success": True, "tasks": parsed_tasks}

if __name__ == "__main__":
    if len(sys.argv) > 1:
        image_path = sys.argv[1]
        final_output = prescription_pipeline(image_path, med_dict)
        
        print("\n[Python] Final JSON Output:", file=sys.stderr)
        print(json.dumps(final_output, indent=2, ensure_ascii=False), file=sys.stderr)

        if final_output.get("error"):
            print(json.dumps({"success": False, "error": final_output["error"]}), file=sys.stdout)
            sys.exit(0)
        else:
            json_output_string = json.dumps(final_output, ensure_ascii=False)
            sys.stdout.buffer.write(json_output_string.encode('utf-8'))
    else:
        error_msg = {"success": False, "error": "No image path provided to Python script."}
        print(json.dumps(error_msg), file=sys.stdout)
        sys.exit(0)