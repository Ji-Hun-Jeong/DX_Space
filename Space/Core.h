#pragma once
class Core
{
// Start
public:
	bool Init();
	void Update(float dt);
	void Render();
	int Progress();

// Window
private:
	bool InitMainWindow();
	HWND m_mainWindow;

public:
	HWND GetMainWindow() { return m_mainWindow; }
	LRESULT MsgProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam);

	float m_fWidth;
	float m_fHeight;
	float GetAspect() const { return m_fWidth / m_fHeight; } 

// SingleTon
	SINGLE(Core)
};

