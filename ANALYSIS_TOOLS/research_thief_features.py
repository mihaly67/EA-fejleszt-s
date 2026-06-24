import json
import re

def search_knowledge_base():
    """
    Scans the Thief's Library (knowledge_base_thiefs_library.jsonl)
    to see what features are used in RL/ML environments (FinRL, Hummingbot).
    Specifically looking for:
    1. Order Flow / Microstructure features (Bid/Ask Volume, imbalance).
    2. Short-term Momentum (RSI, CCI, MACD) vs "Hybrid" concepts.
    """

    keywords = {
        "Microstructure": ["order_book", "bid_ask", "imbalance", "depth", "flow", "liquidity"],
        "Momentum": ["rsi", "macd", "cci", "momentum", "stoch"],
        "Hybrid_Concepts": ["kalman", "filter", "pulse", "velocity", "acceleration", "regime"]
    }

    hits = {k: [] for k in keywords}

    print("🔍 Scanning Thief's Library for Feature Engineering patterns...")

    try:
        with open("Knowledge_Base/knowledge_base_thiefs_library.jsonl", "r", encoding="utf-8") as f:
            for line in f:
                entry = json.loads(line)
                code = entry.get("code", "").lower()
                filename = entry.get("filename", "")

                # Check for hits
                for category, terms in keywords.items():
                    for term in terms:
                        if term in code:
                            # Context extraction (simple)
                            if "feature" in code or "observation" in code or "state" in code:
                                hits[category].append(f"{filename} (term: {term})")
                                break # Count file once per category

    except FileNotFoundError:
        print("❌ Knowledge Base file not found.")
        return

    print("\n📊 FINDINGS:")
    for cat, items in hits.items():
        print(f"\n--- {cat} ({len(items)} files) ---")
        # Show top 5 examples
        for item in items[:5]:
            print(f"  - {item}")

    # SPECIFIC VERDICT GENERATION
    print("\n⚖️ VERDICT ON HYBRID INDICATORS:")

    micro_count = len(hits["Microstructure"])
    hybrid_count = len(hits["Hybrid_Concepts"])

    if micro_count > 50:
        print("✅ ORDER FLOW IS VITAL: The library heavily relies on microstructure (Flow/Imbalance).")
        print("   -> Your 'HybridFlowIndicator' is likely VERY VALUABLE for RL.")
    else:
        print("⚠️ Order Flow is less emphasized (Surprising).")

    if hybrid_count > 10:
        print("✅ ADVANCED MATH IS USED: Kalman filters and velocity checks are present.")
        print("   -> Your 'Hybrid Momentum' (Kalman/Pulse) fits the 'Institutional' profile.")
    else:
        print("ℹ️ Standard indicators (RSI/MACD) dominate. Hybrid might be an 'Edge' or 'Overkill'.")

if __name__ == "__main__":
    search_knowledge_base()
