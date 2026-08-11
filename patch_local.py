import re

file_path = "Micro_LGBM/src/mt5_live_copilot.py"
with open(file_path, "r", encoding="utf-8") as f:
    text = f.read()

find_ping = """                                else:
                                    try:
                                        client.sendall("PRED|0|0.33|0.33|0.34\\n".encode('utf-8'))
                                    except:
                                        pass
                    except Exception as inner_e:"""

# EA sends a lot of ticks, sometimes 50 a second. We shouldn't send back 50 strings a second,
# that overflows EA's Read Buffer!
# Let's throttle the fake ping to only send every 10 ticks.
repl_ping = """                                else:
                                    # Throttle the PING to prevent overwhelming EA buffer
                                    if len(current_bar_ticks) % 10 == 0:
                                        try:
                                            client.sendall("PRED|0|0.33|0.33|0.34\\n".encode('utf-8'))
                                        except:
                                            pass
                    except Exception as inner_e:"""
text = text.replace(find_ping, repl_ping)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(text)
