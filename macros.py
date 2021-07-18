import pyautogui, time, random;

pyautogui.FAILSAFE = True
i = 0
delay = 0.570
time.sleep(2)
print('Hellow')
while(i<10):
    pyautogui.press('D')
    time.sleep(delay)
    pyautogui.press('D')
    time.sleep(delay)
    pyautogui.press('S')
    time.sleep(delay)
    pyautogui.press('S')
    time.sleep(delay)
    pyautogui.press('A')
    time.sleep(delay)
    pyautogui.press('A')
    time.sleep(delay)
    pyautogui.press('W')
    time.sleep(delay)
    pyautogui.press('W')
    time.sleep(delay)