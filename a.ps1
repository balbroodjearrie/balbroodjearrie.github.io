<#
.SYNOPSIS
    ARON.exe - THE EYE | Analog Horror Experience
    Created by ARON
.DESCRIPTION
    A harmless, intense analog-horror experience.
    Press ESC or click [ESC] Sluiten to close (press ESC twice to force immediate exit).
    Press M to toggle sound on/off.
.NOTES
    Requirements : Windows 10/11, PowerShell 5.1+
    Admin        : NOT required
    Dependencies : None (uses built-in .NET)
    Safety       : Does NOT access personal files, collect data, modify settings,
                   or create persistence. Opens built-in Notepad with a temp note on exit.
#>

& {
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$cs = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.IO;
using System.Media;
using System.Windows.Forms;

namespace AronEye
{
public class AronForm : Form
{
    public bool ExitRequested = false;

    // ── Timer & clock ───────────────────────────────────────────────────
    private System.Windows.Forms.Timer tmr;
    private DateTime t0, realStart;
    private Random R = new Random();
    private float T;
    private bool ready;

    // ── Closing sequence (ESC) ──────────────────────────────────────────
    private bool closing;
    private float closeStart;
    private float closeDuration = 3.0f;

    // ── Fonts ────────────────────────────────────────────────────────────
    private Font fStream, fEye, fMiniEye, fMsg, fBig, fNote, fTitle, fDiag, fSmall, fVhs, fHuge, fBsodBig, fBsodTxt;

    // ── Animated state ──────────────────────────────────────────────────
    private float eyeOpen, colorMix, glitchLvl, veinA;
    private float shakeX, shakeY, lookX, lookY, pupilScale = 1f, eyeLunge = 1f;
    private float scareEnd, shadowEnd, hugeTextEnd, rewindEnd, camFlashEnd;
    private bool mouseNearExit;
    private int W, H, CX, CY;

    // ── Ghost second cursor ─────────────────────────────────────────────
    private float ghostX, ghostY;

    // ── Keyboard panic reaction ─────────────────────────────────────────
    private float keyFlashEnd;
    private string lastKeyStr = "";

    // ── Growing dead-pixel web ──────────────────────────────────────────
    private List<Point> deadPixels = new List<Point>();

    // ── Dark background digital stream ──────────────────────────────────
    private float[] dX, dY, dSpd;
    private int[] dLen;
    private int dCount;

    // ── Blood drips & glass splatters ───────────────────────────────────
    private List<float[]> blood = new List<float[]>();
    private List<float[]> eyeSpawnPts = new List<float[]>();
    private List<float[]> splatters = new List<float[]>();
    private bool splat1Done, splat2Done;

    // ── Infected mouse cursor trail ─────────────────────────────────────
    private List<PointF> mouseTrail = new List<PointF>();

    // ── Coordinated center messages ─────────────────────────────────────
    private string[] mText;
    private float[] mShow, mDur, mRelY;
    private int[] mFx, mR, mG, mB;
    private bool[] mBig;
    private int mCount;

    // ── Simulated left-edge status sidebar ──────────────────────────────
    private string[] sbText;
    private float[] sbShow;
    private int[] sbR, sbG, sbB;
    private int sbCount;

    // ── Live-typed Notepad windows (strictly in outer corners) ──────────
    private int[] npX, npY, npW, npH;
    private string[] npTtl, npBdy;
    private float[] npShow, npFade, npRate;
    private int npCount;

    // ── Classic [X] Windows error popups (strictly in outer corners) ────
    private int[] erX, erY;
    private string[] erTtl, erBdy;
    private float[] erShow, erFade;
    private int erCount;

    // ── Sound (in-memory PCM WAV) ───────────────────────────────────────
    private bool soundOn = true;
    private int audioStage = -1; // 0=calm, 1=silence, 2=screech, 3=tense, 4=pitchDrop, 5=powerDown
    private SoundPlayer calmPlayer, tensePlayer, screechPlayer, pitchDropPlayer, powerDownPlayer, activePlayer;
    private MemoryStream calmStream, tenseStream, screechStream, pitchDropStream, powerDownStream;
    private List<PointF> ghostMarks = new List<PointF>();
    private int SW, SH;

    // ═══════════════════════════════════════════════════════════════════
    //  CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════
    public AronForm()
    {
        SW = Screen.PrimaryScreen.Bounds.Width;
        SH = Screen.PrimaryScreen.Bounds.Height;
        ghostX = SW * 0.15f;
        ghostY = SH * 0.18f;

        this.SetStyle(
            ControlStyles.AllPaintingInWmPaint |
            ControlStyles.UserPaint |
            ControlStyles.DoubleBuffer |
            ControlStyles.OptimizedDoubleBuffer, true);
        this.WindowState     = FormWindowState.Maximized;
        this.FormBorderStyle = FormBorderStyle.None;
        this.BackColor       = Color.Black;
        this.TopMost         = true;
        this.KeyPreview      = true;
        this.Text            = "ARON.exe";
        this.Cursor          = Cursors.Cross;

        fStream  = new Font("Consolas", 9.5f, FontStyle.Bold);
        fEye     = new Font("Consolas", 9.5f, FontStyle.Bold);
        fMiniEye = new Font("Consolas", 6.5f, FontStyle.Bold);
        fMsg     = new Font("Consolas", 15.5f, FontStyle.Regular);
        fBig     = new Font("Consolas", 40f, FontStyle.Bold);
        fNote    = new Font("Consolas", 10f);
        fTitle   = new Font("Segoe UI", 9f, FontStyle.Regular);
        fDiag    = new Font("Consolas", 9.5f, FontStyle.Bold);
        fSmall   = new Font("Segoe UI", 8f);
        fVhs     = new Font("Consolas", 10.5f, FontStyle.Bold);
        fHuge    = new Font("Consolas", 78f, FontStyle.Bold);
        fBsodBig = new Font("Segoe UI", 72f, FontStyle.Regular);
        fBsodTxt = new Font("Segoe UI", 16f, FontStyle.Regular);

        InitStream();
        InitTimeline();
        InitAudio();

        this.KeyDown += delegate(object s, KeyEventArgs e) {
            if (e.KeyCode == Keys.Escape) { TriggerExit(); return; }
            if (e.KeyCode == Keys.M)      { ToggleSound(); return; }
            // Live keyboard panic reaction
            if (!closing)
            {
                lastKeyStr = e.KeyCode.ToString();
                if (lastKeyStr.Length > 1) lastKeyStr = lastKeyStr.Substring(0, 1);
                keyFlashEnd = T + 0.50f;
                pupilScale = 0.55f;
            }
        };
        this.MouseClick += delegate(object s, MouseEventArgs e) {
            if (e.X >= this.ClientSize.Width - 96 && e.Y <= 34) TriggerExit();
        };

        tmr = new System.Windows.Forms.Timer();
        tmr.Interval = 36;
        tmr.Tick += delegate {
            T = (float)(DateTime.Now - t0).TotalSeconds;
            UpdateState();
            Invalidate();
        };

        ready = true;
        t0 = DateTime.Now;
        realStart = DateTime.Now;
        SetAudioStage(0);
        tmr.Start();
    }

    // ═══════════════════════════════════════════════════════════════════
    //  IN-MEMORY ANALOG AUDIO (calm, pitch-drop, screech, tense)
    // ═══════════════════════════════════════════════════════════════════
    private void InitAudio()
    {
        try
        {
            calmStream      = BuildDroneWav(4.0, 50.0, 51.8, 0.04, 1.8, false);
            tenseStream     = BuildDroneWav(4.0, 44.0, 47.2, 0.12, 0.55, true);
            screechStream   = BuildScreechWav();
            pitchDropStream = BuildPitchDropWav();
            powerDownStream = BuildPowerDownWav();

            calmPlayer      = new SoundPlayer(calmStream);      calmPlayer.Load();
            tensePlayer     = new SoundPlayer(tenseStream);     tensePlayer.Load();
            screechPlayer   = new SoundPlayer(screechStream);   screechPlayer.Load();
            pitchDropPlayer = new SoundPlayer(pitchDropStream); pitchDropPlayer.Load();
            powerDownPlayer = new SoundPlayer(powerDownStream); powerDownPlayer.Load();
        }
        catch {}
    }

    private MemoryStream BuildDroneWav(double sec, double f1, double f2, double hissAmt, double beatInt, bool heavyBass)
    {
        int sr = 11025, n = (int)(sr * sec);
        byte[] d = new byte[44 + n * 2];
        WriteWavHeader(d, sr, n);
        for (int i = 0; i < n; i++)
        {
            double t = (double)i / sr;
            double hum = Math.Sin(2.0 * Math.PI * f1 * t) * 0.36
                       + Math.Sin(2.0 * Math.PI * f2 * t) * 0.32
                       + Math.Sin(2.0 * Math.PI * (f1 * 1.5) * t) * 0.10;
            if (heavyBass) hum += Math.Sin(2.0 * Math.PI * 36.0 * t) * 0.28;
            double hiss = (R.NextDouble() * 2.0 - 1.0) * hissAmt;
            double bp = t % beatInt;
            double thump = (bp < 0.11) ? Math.Sin(2.0 * Math.PI * 38.0 * bp) * (1.0 - bp / 0.11) * (heavyBass ? 0.65 : 0.45) : 0.0;
            double s = Math.Max(-1.0, Math.Min(1.0, (hum + hiss + thump) * 0.46));
            short v = (short)(s * 32767);
            d[44 + i * 2] = (byte)(v & 0xFF); d[44 + i * 2 + 1] = (byte)((v >> 8) & 0xFF);
        }
        return new MemoryStream(d);
    }

    private MemoryStream BuildPowerDownWav()
    {
        int sr = 11025, n = (int)(sr * 0.70);
        byte[] d = new byte[44 + n * 2];
        WriteWavHeader(d, sr, n);
        double phase = 0.0;
        for (int i = 0; i < n; i++)
        {
            double frac = (double)i / n;
            double freq = 140.0 * Math.Pow(1.0 - frac * 0.85, 2.0);
            phase += 2.0 * Math.PI * freq / sr;
            double thud = (frac < 0.08) ? Math.Sin(2.0 * Math.PI * 45.0 * frac) * 0.5 : 0.0;
            double env = 1.0 - frac;
            double s = Math.Max(-1.0, Math.Min(1.0, (Math.Sin(phase) * 0.55 + thud) * env));
            short v = (short)(s * 32767);
            d[44 + i * 2] = (byte)(v & 0xFF); d[44 + i * 2 + 1] = (byte)((v >> 8) & 0xFF);
        }
        return new MemoryStream(d);
    }

    private MemoryStream BuildPitchDropWav()
    {
        int sr = 11025, n = (int)(sr * 1.8);
        byte[] d = new byte[44 + n * 2];
        WriteWavHeader(d, sr, n);
        double phase = 0.0;
        for (int i = 0; i < n; i++)
        {
            double frac = (double)i / n;
            double freq = 52.0 - frac * 34.0; // drops 52Hz -> 18Hz!
            phase += 2.0 * Math.PI * freq / sr;
            double env = 1.0 - frac * 0.4;
            double s = Math.Max(-1.0, Math.Min(1.0, Math.Sin(phase) * env * 0.45));
            short v = (short)(s * 32767);
            d[44 + i * 2] = (byte)(v & 0xFF); d[44 + i * 2 + 1] = (byte)((v >> 8) & 0xFF);
        }
        return new MemoryStream(d);
    }

    private MemoryStream BuildScreechWav()
    {
        int sr = 11025, n = (int)(sr * 0.55);
        byte[] d = new byte[44 + n * 2];
        WriteWavHeader(d, sr, n);
        for (int i = 0; i < n; i++)
        {
            double t = (double)i / sr;
            double env = Math.Max(0.0, 1.0 - t / 0.55);
            double eas = Math.Sin(2.0 * Math.PI * 853.0 * t) * 0.35 + Math.Sin(2.0 * Math.PI * 960.0 * t) * 0.35;
            double noise = (R.NextDouble() * 2.0 - 1.0) * 0.45;
            double s = Math.Max(-1.0, Math.Min(1.0, (eas + noise) * env * 0.55));
            short v = (short)(s * 32767);
            d[44 + i * 2] = (byte)(v & 0xFF); d[44 + i * 2 + 1] = (byte)((v >> 8) & 0xFF);
        }
        return new MemoryStream(d);
    }

    private void WriteWavHeader(byte[] d, int sr, int n)
    {
        WriteAscii(d, 0, "RIFF"); WriteInt32(d, 4, 36 + n * 2); WriteAscii(d, 8, "WAVE");
        WriteAscii(d, 12, "fmt "); WriteInt32(d, 16, 16); WriteInt16(d, 20, 1); WriteInt16(d, 22, 1);
        WriteInt32(d, 24, sr); WriteInt32(d, 28, sr * 2); WriteInt16(d, 32, 2); WriteInt16(d, 34, 16);
        WriteAscii(d, 36, "data"); WriteInt32(d, 40, n * 2);
    }
    private void WriteAscii(byte[] b, int off, string s) { for (int i = 0; i < s.Length; i++) b[off + i] = (byte)s[i]; }
    private void WriteInt32(byte[] b, int off, int v) { b[off]=(byte)(v&255); b[off+1]=(byte)((v>>8)&255); b[off+2]=(byte)((v>>16)&255); b[off+3]=(byte)((v>>24)&255); }
    private void WriteInt16(byte[] b, int off, short v) { b[off]=(byte)(v&255); b[off+1]=(byte)((v>>8)&255); }

    private void SetAudioStage(int stage)
    {
        if (audioStage == stage) return;
        audioStage = stage;
        try
        {
            if (activePlayer != null) activePlayer.Stop();
            if (!soundOn) return;
            if      (stage == 0 && calmPlayer      != null) { activePlayer = calmPlayer;      activePlayer.PlayLooping(); }
            else if (stage == 2 && screechPlayer   != null) { activePlayer = screechPlayer;   activePlayer.Play(); }
            else if (stage == 3 && tensePlayer     != null) { activePlayer = tensePlayer;     activePlayer.PlayLooping(); }
            else if (stage == 4 && pitchDropPlayer != null) { activePlayer = pitchDropPlayer; activePlayer.Play(); }
            else if (stage == 5 && powerDownPlayer != null) { activePlayer = powerDownPlayer; activePlayer.Play(); }
            else                                            { activePlayer = null; }
        }
        catch {}
    }

    private void ToggleSound()
    {
        soundOn = !soundOn;
        if (!soundOn) { try { if (activePlayer != null) activePlayer.Stop(); } catch {} }
        else { int st = audioStage; audioStage = -1; SetAudioStage(st); }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  INIT DARK DIGITAL BACKGROUND STREAM & TIMELINE
    // ═══════════════════════════════════════════════════════════════════
    private void InitStream()
    {
        int spacing = 26;
        dCount = SW / spacing + 2;
        dX = new float[dCount]; dY = new float[dCount]; dSpd = new float[dCount]; dLen = new int[dCount];
        for (int i = 0; i < dCount; i++)
        {
            dX[i] = i * spacing; dY[i] = R.Next(-SH, 0);
            dSpd[i] = 1.0f + (float)R.NextDouble() * 2.8f; dLen[i] = R.Next(4, 14);
        }
    }

    private void InitTimeline()
    {
        mCount = 13;
        mText = new string[mCount]; mShow = new float[mCount]; mDur = new float[mCount];
        mFx = new int[mCount]; mRelY = new float[mCount]; mBig = new bool[mCount];
        mR = new int[mCount]; mG = new int[mCount]; mB = new int[mCount];
        int mi = 0;
        SM(mi++, "hallo.",                                          10.5f, 3.4f, 0, .80f, false, 115, 205, 255);
        SM(mi++, "waarom kijk je nog.",                             14.2f, 2.2f, 2, .80f, false, 100, 195, 255);
        SM(mi++, "je dacht dat je dit zelf onder controle had.",    20.4f, 3.4f, 1, .80f, false, 215, 45,  45);
        SM(mi++, "ik zie je muis bewegen.",                         24.5f, 3.2f, 2, .80f, false, 220, 30,  30);
        SM(mi++, "druk maar op esc. ik wacht wel.",                 29.0f, 3.4f, 0, .80f, false, 225, 20,  20);
        SM(mi++, "het heeft geen zin om weg te kijken.",            34.8f, 3.2f, 1, .80f, false, 220, 15,  15);
        SM(mi++, "ik ben nog niet klaar met je.",                   38.2f, 2.3f, 2, .80f, false, 235, 0,   0);
        SM(mi++, "ARON.exe",                                        41.8f, 40f,  1, .10f, true,  220, 15,  15);
        SM(mi++, "ik kan je zien.",                                 43.0f, 38f,  2, .21f, false, 210, 40,  40);
        SM(mi++, "je dacht dat het voorbij was.",                  45.5f, 5.0f, 0, .80f, false, 195, 20,  20);
        SM(mi++, "tot de volgende keer.",                           48.8f, 32f,  2, .86f, false, 175, 10,  10);
        SM(mi++, "CREATED BY ARON",                                 50.8f, 30f,  2, .92f, false, 115, 115, 115);
        SM(mi++, "",                                                99f,   1f,   0, .99f, false, 0, 0, 0);

        sbCount = 6;
        sbText = new string[sbCount]; sbShow = new float[sbCount];
        sbR = new int[sbCount]; sbG = new int[sbCount]; sbB = new int[sbCount];
        int si = 0;
        SB(si++, "Camera       : GEKOPPELD",      6.5f,  100, 185, 235);
        SB(si++, "Microfoon    : LUISTERT",       11.5f, 100, 185, 235);
        SB(si++, "Bureaublad   : GEINDEXEERD",    16.5f, 180, 150, 90);
        SB(si++, "Cursor       : GEVOLGD",        21.5f, 210, 50,  50);
        SB(si++, "Toetsenbord  : ONDERSCHEPT",    26.5f, 215, 30,  30);
        SB(si++, "Uitgang      : GEBLOKKEERD",    31.5f, 225, 15,  15);

        npCount = 6;
        npX = new int[npCount]; npY = new int[npCount];
        npW = new int[npCount]; npH = new int[npCount];
        npTtl = new string[npCount]; npBdy = new string[npCount];
        npShow = new float[npCount]; npFade = new float[npCount]; npRate = new float[npCount];
        int ni = 0;
        SN(ni++, 24,       55,       295, 125, "Naamloos - Kladblok", "hallo.\r\nik weet dat je hier bent.",                         11.8f, 17.5f, 12f);
        SN(ni++, SW - 325, 58,       300, 125, "Naamloos - Kladblok", "dit is geen foutmelding.\r\nstop met bewegen.",                  16.2f, 22.5f, 12f);
        SN(ni++, 24,       SH - 175, 305, 130, "Naamloos - Kladblok", "waarom heb je dit geopend?\r\nje kent de gevolgen.",             21.2f, 28.5f, 12f);
        SN(ni++, SW - 330, SH - 180, 305, 130, "Naamloos - Kladblok", "ik zie waar je naartoe wilt klikken.\r\nhet helpt niet.",       25.5f, 33.5f, 12f);
        SN(ni++, 24,       SH/2-65,  280, 120, "Naamloos - Kladblok", "je bent niet alleen in deze kamer.",                            30.5f, 38.0f, 11f);
        SN(ni++, SW - 305, SH/2-65,  280, 120, "Naamloos - Kladblok", "tot zo.",                                                       35.0f, 40.3f, 11f);

        erCount = 2;
        erX = new int[erCount]; erY = new int[erCount];
        erTtl = new string[erCount]; erBdy = new string[erCount];
        erShow = new float[erCount]; erFade = new float[erCount];
        SE(0, SW - 340, 200, "Systeemwaarschuwing", "Kan ARON.exe niet beeindigen.", 23.0f, 30.0f);
        SE(1, 24,       205, "Beveiliging",         "Onbekende invoer gedetecteerd.", 32.0f, 39.5f);
    }
    private void SM(int i,string t,float sh,float d,int fx,float ry,bool big,int r,int g,int b)
    { mText[i]=t;mShow[i]=sh;mDur[i]=d;mFx[i]=fx;mRelY[i]=ry;mBig[i]=big;mR[i]=r;mG[i]=g;mB[i]=b; }
    private void SB(int i,string t,float sh,int r,int g,int b)
    { sbText[i]=t;sbShow[i]=sh;sbR[i]=r;sbG[i]=g;sbB[i]=b; }
    private void SN(int i,int x,int y,int w,int h,string ttl,string bdy,float sh,float fd,float rt)
    { npX[i]=x;npY[i]=y;npW[i]=w;npH[i]=h;npTtl[i]=ttl;npBdy[i]=bdy;npShow[i]=sh;npFade[i]=fd;npRate[i]=rt; }
    private void SE(int i,int x,int y,string ttl,string bdy,float sh,float fd)
    { erX[i]=x;erY[i]=y;erTtl[i]=ttl;erBdy[i]=bdy;erShow[i]=sh;erFade[i]=fd; }

    // ═══════════════════════════════════════════════════════════════════
    //  STATE UPDATE
    // ═══════════════════════════════════════════════════════════════════
    private void UpdateState()
    {
        if (closing)
        {
            float ct = T - closeStart;
            eyeOpen = Math.Max(0f, 1f - Cf(ct / 2.2f, 0f, 1f));
            glitchLvl = 0.05f;
            shakeX = 0f; shakeY = 0f;
            if (ct >= closeDuration) ForceClose();
            return;
        }

        // Audio stages (includes pitch-drop before BSOD!)
        if      (T < 16.6f)               SetAudioStage(0);
        else if (T >= 16.6f && T < 18.4f) SetAudioStage(4); // Pitch drop!
        else if (T >= 18.4f && T < 20.1f) SetAudioStage(1); // Dead silence during BSOD
        else if (T >= 20.1f && T < 20.8f) SetAudioStage(2); // Screech on BSOD tear
        else if (T >= 20.8f && T < 34.4f) SetAudioStage(3); // Tense fast heartbeat
        else if (T >= 34.4f && T < 35.1f) SetAudioStage(2); // Second scare burst
        else if (T >= 35.1f && T < 40.5f) SetAudioStage(3);
        else if (T >= 40.5f && T < 41.7f) SetAudioStage(1); // Blackout silence
        else                              SetAudioStage(0);

        // Camera flash ("foto gemaakt") at 15.6s
        if (T >= 15.6f && T < 15.76f) camFlashEnd = 15.76f;

        if (T >= 20.1f && T < 20.32f) scareEnd = 20.32f;
        if (T >= 34.4f && T < 34.60f) scareEnd = 34.60f;

        if (T >= 26.2f && T < 26.65f) rewindEnd = 26.65f;
        if (T >= 36.8f && T < 37.25f) rewindEnd = 37.25f;

        // Eye lunge + heartbeat zoom before blackout (35s - 40.5s)
        float targetLunge = 1.0f;
        if (T >= 35.0f && T < 40.5f)
        {
            float zoomProg = Cf((T - 35.0f) / 5.5f, 0f, 1f);
            float hb = (float)Math.Max(0.0, Math.Sin(T * 6.0)) * 0.08f;
            targetLunge = 1.0f + zoomProg * 0.42f + hb;
        }
        if (T < scareEnd) eyeLunge = 1.45f;
        else eyeLunge += (targetLunge - eyeLunge) * 0.14f;

        if (!splat1Done && T >= 20.1f) { splat1Done = true; SpawnSplatters(4); }
        if (!splat2Done && T >= 34.4f) { splat2Done = true; SpawnSplatters(5); }

        if (T > 22f && T < 40.5f && T > shadowEnd && R.NextDouble() < 0.016)
            shadowEnd = T + 0.08f;

        if (T > 20.5f && T < 40.5f && T > hugeTextEnd && R.NextDouble() < 0.025)
            hugeTextEnd = T + 0.14f;

        // Growing dead-pixel web from corners
        if (T > 16f && T < 40.5f && deadPixels.Count < 220 && R.NextDouble() < 0.55)
        {
            if (deadPixels.Count == 0) { deadPixels.Add(new Point(8, 8)); deadPixels.Add(new Point(SW - 10, SH - 10)); }
            Point p = deadPixels[R.Next(deadPixels.Count)];
            int nx = Clamp(p.X + R.Next(-10, 11), 2, SW - 4);
            int ny = Clamp(p.Y + R.Next(-10, 11), 2, SH - 4);
            if (Math.Abs(nx - CX) > 290 || Math.Abs(ny - CY) > 180)
                deadPixels.Add(new Point(nx, ny));
        }

        // Purposeful ghost cursor: targets [ESC] Sluiten & draws marks, then circles the eye
        if (T > 13f && T < 40.5f)
        {
            float tx, ty;
            if (T >= 22.0f && T < 27.5f)
            {
                tx = (W - 65) + (float)Math.Cos(T * 4.5) * 32f;
                ty = 26f + (float)Math.Sin(T * 4.5) * 18f;
                if (ghostMarks.Count < 60 && R.NextDouble() < 0.45)
                    ghostMarks.Add(new PointF(ghostX, ghostY));
            }
            else if (T >= 27.5f)
            {
                tx = CX + (float)Math.Cos(T * 1.4) * 310f;
                ty = CY + (float)Math.Sin(T * 1.4) * 165f;
                if (ghostMarks.Count < 140 && R.NextDouble() < 0.35)
                    ghostMarks.Add(new PointF(ghostX, ghostY));
            }
            else
            {
                tx = 160 + (float)Math.Sin(T * 1.2) * 110f;
                ty = 120 + (float)Math.Cos(T * 0.9) * 60f;
            }
            ghostX += (tx - ghostX) * 0.08f;
            ghostY += (ty - ghostY) * 0.08f;
        }

        // Eye openness
        if      (T < 7.0f)  eyeOpen = 0f;
        else if (T < 10.0f) eyeOpen = (T - 7.0f) / 3f;
        else                eyeOpen = 1f;

        if (T > 19.8f && T < 20.0f) eyeOpen = 0.15f;
        if (T > 28.0f && T < 29.2f) eyeOpen = 0.58f;
        if (T > 33.4f && T < 33.52f) eyeOpen = 0.10f;

        if      (T < 20.1f) colorMix = 0f;
        else if (T < 23.0f) colorMix = (T - 20.1f) / 2.9f;
        else                colorMix = 1f;

        if      (T < 20.1f) glitchLvl = 0.05f;
        else if (T < 40.5f) glitchLvl = 0.42f + (float)Math.Sin(T * 2.4) * 0.22f;
        else                glitchLvl = 0.14f;

        if      (T < 20.1f) veinA = 0f;
        else if (T < 23.5f) veinA = (T - 20.1f) / 3.4f;
        else                veinA = 1f;

        if (T > 20.1f && R.NextDouble() < 0.045)
            pupilScale = (R.Next(2) == 0) ? 1.50f : 0.62f;
        else
            pupilScale += (1.0f - pupilScale) * 0.14f;

        Point mp = this.PointToClient(Cursor.Position);
        mouseNearExit = (mp.X > W - 260 && mp.Y < 130 && T > 11f && T < 40.5f);

        if (T > 20.1f && T < 40.5f)
        {
            mouseTrail.Add(new PointF(mp.X, mp.Y));
            if (mouseTrail.Count > 14) mouseTrail.RemoveAt(0);
        }
        else if (mouseTrail.Count > 0) mouseTrail.Clear();

        if (W > 0 && H > 0)
        {
            float nx = Cf((mp.X - CX) / (W * 0.45f), -1f, 1f);
            float ny = Cf((mp.Y - CY) / (H * 0.45f), -1f, 1f);
            float spd = mouseNearExit ? 0.38f : 0.14f;
            lookX += (nx * 6.5f - lookX) * spd;
            lookY += (ny * 2.8f - lookY) * spd;
        }

        if ((T < scareEnd) || (T < rewindEnd) || (T < keyFlashEnd) || (glitchLvl > 0.3f && R.NextDouble() < 0.25))
        {
            float mult = (T < scareEnd) ? 26f : 11f * glitchLvl;
            shakeX = (float)(R.NextDouble() - 0.5) * mult;
            shakeY = (float)(R.NextDouble() - 0.5) * mult * 0.6f;
        }
        else { shakeX = 0f; shakeY = 0f; }

        if (T > 20.5f && eyeSpawnPts.Count > 0)
        {
            double ch = (T < 40.5f) ? 0.32 : 0.14;
            if (R.NextDouble() < ch)
            {
                float[] pt = eyeSpawnPts[R.Next(eyeSpawnPts.Count)];
                blood.Add(new float[] {
                    pt[0] + (float)(R.NextDouble() - 0.5) * 5f, pt[1],
                    0.45f + (float)R.NextDouble() * 1.1f,
                    3.5f + (float)R.NextDouble() * 4.5f,
                    22f + (float)R.NextDouble() * 48f, 235f
                });
            }
        }
        if (T > 28.0f && R.NextDouble() < 0.10)
        {
            blood.Add(new float[] {
                R.Next(30, Math.Max(60, W - 30)), 0f,
                0.7f + (float)R.NextDouble() * 1.4f,
                3.0f + (float)R.NextDouble() * 4.0f,
                25f + (float)R.NextDouble() * 55f, 200f
            });
        }
        for (int i = blood.Count - 1; i >= 0; i--)
        {
            blood[i][1] += blood[i][2];
            blood[i][2] = Math.Min(7.5f, blood[i][2] + 0.065f);
            blood[i][4] = Math.Min(115f, blood[i][4] + blood[i][2] * 0.45f);
            if (blood[i][1] > SH + 120) blood.RemoveAt(i);
        }
    }

    private void SpawnSplatters(int count)
    {
        for (int i = 0; i < count; i++)
        {
            float sx = (R.Next(2) == 0) ? R.Next(120, Math.Max(140, SW / 3)) : R.Next(SW * 2 / 3, Math.Max(SW * 2 / 3 + 20, SW - 120));
            float sy = R.Next(80, Math.Max(100, SH - 120));
            splatters.Add(new float[] { sx, sy, 6f + (float)R.NextDouble() * 10f, 14f + (float)R.NextDouble() * 28f, T });
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  PAINT
    // ═══════════════════════════════════════════════════════════════════
    protected override void OnPaint(PaintEventArgs e)
    {
        if (!ready) { e.Graphics.Clear(Color.Black); return; }
        Graphics g = e.Graphics;
        g.SmoothingMode     = SmoothingMode.AntiAlias;
        g.TextRenderingHint = TextRenderingHint.SingleBitPerPixelGridFit;
        W  = ClientSize.Width;  H  = ClientSize.Height;
        CX = W / 2;             CY = H / 2;
        g.Clear(Color.Black);

        if (closing) { PaintClosingSequence(g); return; }
        if (T >= 40.5f && T < 41.7f) { PaintUI(g); return; }
        if (T < camFlashEnd) { g.Clear(Color.White); return; }
        if (T >= 18.4f && T < 20.1f) { PaintFakeBsod(g); PaintUI(g); return; }
        if (T < scareEnd) { PaintScareFlash(g); return; }

        g.TranslateTransform(shakeX, shakeY);

        PaintDigitalStream(g);
        PaintDeadPixelWeb(g);
        PaintHugeBgText(g);
        PaintShadowEntity(g);
        PaintCornerEyes(g);
        PaintSmoothEyeGlow(g);
        PaintEyeEchoTunnel(g);
        PaintAsciiEye(g);
        PaintScreenCrack(g);
        PaintGlassSplatters(g);
        PaintBlood(g);
        PaintDigitalRot(g);
        PaintVhsGlitches(g);
        PaintVhsRewind(g);
        PaintHeartbeatVignette(g);
        PaintEcgLine(g);
        PaintSidebar(g);
        PaintMsgs(g);
        PaintNpads(g);
        PaintErrorPopups(g);
        PaintHijackedDialog(g);
        PaintFakeTaskManager(g);
        PaintKeyPanicFeedback(g);
        PaintCursorTrail(g);
        PaintGhostCursor(g);
        PaintExitReaction(g);

        g.ResetTransform();
        PaintViewfinder(g);
        PaintVhsHud(g);
        PaintUI(g);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  DRAW: ESC SLOW CLOSING SEQUENCE
    // ═══════════════════════════════════════════════════════════════════
    private void PaintClosingSequence(Graphics g)
    {
        PaintDigitalStream(g);
        if (eyeOpen > 0.02f) PaintAsciiEye(g);
        PaintHeartbeatVignette(g);

        float ct = T - closeStart;
        int a = Clamp((int)(Cf(ct / 0.5f, 0f, 1f) * 240), 0, 255);
        string farewell = "volgende keer krijg ik je wel.";
        SizeF sz = g.MeasureString(farewell, fMsg);
        using (SolidBrush b = new SolidBrush(Color.FromArgb(a, 210, 25, 25)))
            g.DrawString(farewell, fMsg, b, (W - sz.Width) / 2f, H * 0.78f);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  DRAW: FAKE BSOD THAT TEARS AWAY (18.4s - 20.1s)
    // ═══════════════════════════════════════════════════════════════════
    private void PaintFakeBsod(Graphics g)
    {
        g.Clear(Color.FromArgb(0, 120, 215));
        using (SolidBrush wb = new SolidBrush(Color.White))
        {
            g.DrawString(":(", fBsodBig, wb, W * 0.14f, H * 0.18f);
            g.DrawString("Er is een probleem met uw pc opgetreden en deze moet opnieuw worden opgestart.\r\nFoutcode: ARON_CORE_OVERRIDE\r\n\r\n0% voltooid", fBsodTxt, wb, W * 0.14f, H * 0.38f);
        }
        // Tear apart from 19.65s to 20.1s
        if (T >= 19.65f)
        {
            for (int i = 0; i < 16; i++)
            {
                int ry = R.Next(H), rh = R.Next(12, 48);
                using (SolidBrush bb = new SolidBrush(Color.FromArgb(R.Next(160, 255), R.Next(2) == 0 ? 0 : 120, 0, 0)))
                    g.FillRectangle(bb, 0, ry, W, rh);
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  DRAW: GHOST CURSOR, ECG MONITOR, ECHO TUNNEL, DEAD PIXELS, KEY FEEDBACK
    // ═══════════════════════════════════════════════════════════════════
    private void PaintGhostCursor(Graphics g)
    {
        if (T < 13f || T > 40.5f) return;
        for (int i = 0; i < ghostMarks.Count; i++)
        {
            PointF gm = ghostMarks[i];
            using (SolidBrush mb = new SolidBrush(Color.FromArgb(130, 195, 10, 10)))
                g.FillEllipse(mb, gm.X - 2, gm.Y - 2, 4, 4);
        }
        int x = (int)ghostX, y = (int)ghostY;
        Point[] arrow = {
            new Point(x, y), new Point(x, y + 18), new Point(x + 4, y + 14),
            new Point(x + 8, y + 22), new Point(x + 11, y + 20),
            new Point(x + 7, y + 12), new Point(x + 13, y + 12)
        };
        using (SolidBrush wb = new SolidBrush(Color.FromArgb(220, 245, 245, 245)))
        using (Pen bp = new Pen(Color.Black, 1.3f))
        {
            g.FillPolygon(wb, arrow);
            g.DrawPolygon(bp, arrow);
        }
    }

    private void PaintFakeTaskManager(Graphics g)
    {
        if (T < 33.5f || T > 40.3f) return;
        int x = 24, y = 55, w = 320, h = 195;
        bool corrupted = (T >= 35.2f);

        using (SolidBrush bg = new SolidBrush(Color.FromArgb(245, 245, 245)))
            g.FillRectangle(bg, x, y, w, h);
        using (Pen bp = new Pen(Color.FromArgb(120, 120, 120), 1))
            g.DrawRectangle(bp, x, y, w, h);
        using (SolidBrush tb = new SolidBrush(Color.White))
            g.FillRectangle(tb, x + 1, y + 1, w - 2, 26);
        using (SolidBrush tt = new SolidBrush(Color.Black))
            g.DrawString(corrupted ? "Taakbeheer (Reageert niet)" : "Taakbeheer", fTitle, tt, x + 8, y + 5);

        using (SolidBrush hd = new SolidBrush(Color.FromArgb(230, 230, 230)))
            g.FillRectangle(hd, x + 1, y + 28, w - 2, 22);
        using (SolidBrush ht = new SolidBrush(Color.FromArgb(50, 50, 50)))
            g.DrawString("Naam                     CPU      Schijf", fSmall, ht, x + 8, y + 32);

        // Process rows
        using (SolidBrush nt = new SolidBrush(Color.FromArgb(30, 30, 30)))
        {
            g.DrawString("Windows Verkenner        1%       0%", fSmall, nt, x + 8, y + 58);
            g.DrawString("Desktop Window Mgr       2%       0%", fSmall, nt, x + 8, y + 80);
        }

        // ARON.exe highlighted row
        Color rowBg = corrupted ? Color.FromArgb(180, 15, 15) : Color.FromArgb(255, 210, 210);
        Color rowFg = corrupted ? Color.White : Color.FromArgb(165, 0, 0);
        using (SolidBrush rb = new SolidBrush(rowBg))
            g.FillRectangle(rb, x + 2, y + 102, w - 4, 24);
        string aronRow = corrupted ? "ARON.exe               ???%     ACTIEF" : "ARON.exe                99%      99%";
        using (SolidBrush rt = new SolidBrush(rowFg))
            g.DrawString(aronRow, fSmall, rt, x + 8, y + 106);

        DrawWinBtn(g, x + w - 125, y + h - 36, 112, 26, corrupted ? "Toegang geweigerd" : "Taak beeindigen", corrupted);
    }

    private void PaintEcgLine(Graphics g)
    {
        if (T < 5f || T > 41.7f) return;
        float baseY = H * 0.72f;
        int x0 = CX - 180, w = 360;
        bool flatline = (T >= 39.2f);
        Color ec = Lerp(Color.FromArgb(140, 0, 190, 255), Color.FromArgb(170, 220, 20, 20), colorMix);
        using (Pen ep = new Pen(ec, 1.5f))
        {
            float prevY = baseY;
            for (int i = 0; i < w; i += 4)
            {
                float y = baseY;
                if (!flatline)
                {
                    float speed = (T > 20.1f) ? 3.2f : 1.1f;
                    float phase = ((i / (float)w) * 2.5f - T * speed) % 1.0f;
                    if (phase < 0) phase += 1.0f;
                    if (phase > 0.40f && phase < 0.45f) y -= 6f;
                    else if (phase >= 0.45f && phase < 0.49f) y += 8f;
                    else if (phase >= 0.49f && phase < 0.54f) y -= 22f;
                    else if (phase >= 0.54f && phase < 0.59f) y += 10f;
                }
                if (i > 0) g.DrawLine(ep, x0 + i - 4, prevY, x0 + i, y);
                prevY = y;
            }
        }
    }

    private void PaintEyeEchoTunnel(Graphics g)
    {
        if (T < 35.5f || T > 40.5f) return;
        for (int k = 1; k <= 3; k++)
        {
            float sc = 1.0f + ((T * 1.4f + k * 0.33f) % 1.0f) * 1.6f;
            int rx = (int)(260 * sc), ry = (int)(110 * sc);
            int a = Clamp((int)((2.6f - sc) * 45), 5, 75);
            using (Pen ep = new Pen(Color.FromArgb(a, 200, 0, 0), 2f))
                g.DrawEllipse(ep, CX - rx, CY - ry, rx * 2, ry * 2);
        }
    }

    private void PaintDeadPixelWeb(Graphics g)
    {
        for (int i = 0; i < deadPixels.Count; i++)
        {
            Point p = deadPixels[i];
            using (SolidBrush b = new SolidBrush((i % 4 == 0) ? Color.FromArgb(180, 170, 0, 0) : Color.FromArgb(200, 15, 15, 15)))
                g.FillRectangle(b, p.X, p.Y, 3, 3);
        }
    }

    private void PaintKeyPanicFeedback(Graphics g)
    {
        if (T >= keyFlashEnd || string.IsNullOrEmpty(lastKeyStr)) return;
        using (SolidBrush rb = new SolidBrush(Color.FromArgb(32, 220, 0, 0)))
            g.FillRectangle(rb, 0, 0, W, H);
        using (SolidBrush kb = new SolidBrush(Color.FromArgb(200, 230, 30, 30)))
            g.DrawString("[ " + lastKeyStr + " ]", fBig, kb, CX - 55 + R.Next(-8, 9), H * 0.85f);
        // Reflection inside iris
        using (SolidBrush ib = new SolidBrush(Color.FromArgb(130, 255, 255, 255)))
            g.DrawString(lastKeyStr, fMsg, ib, CX + lookX * 5 - 8, CY + lookY * 5 - 10);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  DRAW: CRACK, GLASS SPLATTERS, CURSOR TRAIL, REWIND
    // ═══════════════════════════════════════════════════════════════════
    private void PaintScreenCrack(Graphics g)
    {
        if (T < 20.1f || T > 40.5f) return;
        float alpha = Cf((T - 20.1f) / 1.5f, 0f, 1f);
        int a = Clamp((int)(alpha * 165), 0, 255);
        using (Pen glow = new Pen(Color.FromArgb(a / 3, 210, 0, 0), 4f))
        using (Pen crack = new Pen(Color.FromArgb(a, 235, 235, 235), 1.4f))
        {
            Point[] p1 = { new Point(0, 0), new Point(W/8, H/6), new Point(W/5, H/4), new Point(CX - 285, CY - 55) };
            Point[] p2 = { new Point(W/5, H/4), new Point(W/4 - 30, H/2 - 40) };
            Point[] p3 = { new Point(W, H), new Point(W - W/7, H - H/5), new Point(CX + 295, CY + 65) };
            g.DrawLines(glow, p1);  g.DrawLines(crack, p1);
            g.DrawLines(glow, p2);  g.DrawLines(crack, p2);
            g.DrawLines(glow, p3);  g.DrawLines(crack, p3);
        }
    }

    private void PaintGlassSplatters(Graphics g)
    {
        for (int i = 0; i < splatters.Count; i++)
        {
            float[] sp = splatters[i];
            float age = T - sp[4];
            if (age > 14f) continue;
            int a = Clamp((int)((1f - age / 14f) * 185), 0, 200);
            float drip = age * 7.5f;
            using (SolidBrush b = new SolidBrush(Color.FromArgb(a, 145, 0, 0)))
            {
                g.FillEllipse(b, sp[0] - sp[2], sp[1] - sp[2], sp[2] * 2f, sp[2] * 1.6f);
                g.FillEllipse(b, sp[0] - sp[2] * 0.25f, sp[1], sp[2] * 0.5f, sp[3] + drip);
            }
        }
    }

    private void PaintCursorTrail(Graphics g)
    {
        for (int i = 0; i < mouseTrail.Count; i++)
        {
            float frac = (float)(i + 1) / mouseTrail.Count;
            int a = Clamp((int)(frac * 150), 10, 160);
            float sz = 4f + frac * 7f;
            PointF pt = mouseTrail[i];
            using (SolidBrush b = new SolidBrush(Color.FromArgb(a, 220, 10, 10)))
                g.FillRectangle(b, pt.X - sz / 2f + R.Next(-2, 3), pt.Y - sz / 2f, sz, sz * 0.45f);
        }
    }

    private void PaintVhsRewind(Graphics g)
    {
        if (T >= rewindEnd) return;
        for (int i = 0; i < 14; i++)
        {
            int ry = R.Next(H);
            using (SolidBrush b = new SolidBrush(Color.FromArgb(R.Next(55, 140), 220, 220, 220)))
                g.FillRectangle(b, 0, ry, W, R.Next(2, 10));
        }
        using (SolidBrush tb = new SolidBrush(Color.FromArgb(220, 240, 240, 240)))
            g.DrawString("<< TERUGSPOELEN", fVhs, tb, 42, 42);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  DRAW: BACKGROUND STREAM, TEXT, SHADOW, CORNER EYES, GLOW
    // ═══════════════════════════════════════════════════════════════════
    private void PaintDigitalStream(Graphics g)
    {
        for (int i = 0; i < dCount; i++)
        {
            dY[i] += dSpd[i];
            if (dY[i] > H + dLen[i] * 16) { dY[i] = -dLen[i] * 16; dSpd[i] = 1.0f + (float)R.NextDouble() * 2.8f; }
            for (int j = 0; j < dLen[i]; j++)
            {
                float cy = dY[i] + j * 16;
                if (cy < -16 || cy > H) continue;
                float br = (float)(j + 1) / dLen[i];
                int a = Clamp((int)(br * 72), 4, 85);
                Color col = (colorMix > 0.4f)
                    ? Color.FromArgb(a, Clamp((int)(145 * br + 30), 0, 255), 10, 10)
                    : Color.FromArgb(a, 40, Clamp((int)(110 * br + 30), 0, 255), Clamp((int)(155 * br + 40), 0, 255));
                using (SolidBrush b = new SolidBrush(col))
                {
                    string ch = R.NextDouble() < 0.2 ? R.Next(16).ToString("X") : R.Next(2).ToString();
                    g.DrawString(ch, fStream, b, dX[i], cy);
                }
            }
        }
    }

    private void PaintHugeBgText(Graphics g)
    {
        if (T >= hugeTextEnd) return;
        string txt = "IK ZIE JE";
        SizeF sz = g.MeasureString(txt, fHuge);
        using (SolidBrush b = new SolidBrush(Color.FromArgb(26, 200, 0, 0)))
            g.DrawString(txt, fHuge, b, (W - sz.Width) / 2f + R.Next(-12, 13), (H - sz.Height) / 2f + R.Next(-8, 9));
    }

    private void PaintShadowEntity(Graphics g)
    {
        if (T >= shadowEnd) return;
        int sx = CX + R.Next(-260, 260), sy = CY + R.Next(-150, 150);
        using (SolidBrush b = new SolidBrush(Color.FromArgb(42, 180, 0, 0)))
            g.DrawString("(  @  )      (  @  )", fMsg, b, sx - 120, sy);
    }

    private void PaintCornerEyes(Graphics g)
    {
        if (T < 22f) return;
        float alpha = Cf((T - 22f) / 4f, 0f, 1f);
        int a = Clamp((int)(alpha * 115), 0, 130);
        int[,] centers = {
            { (int)(W * 0.23f), (int)(H * 0.20f) }, { (int)(W * 0.77f), (int)(H * 0.20f) },
            { (int)(W * 0.23f), (int)(H * 0.80f) }, { (int)(W * 0.77f), (int)(H * 0.80f) }
        };
        for (int idx = 0; idx < 4; idx++)
        {
            int ex = centers[idx, 0], ey = centers[idx, 1];
            int ox = (int)Cf(lookX * 0.35f, -2f, 2f);
            using (SolidBrush sb = new SolidBrush(Color.FromArgb(a, 175, 15, 15)))
            {
                g.DrawString("  .---.  ", fMiniEye, sb, ex - 28, ey - 10);
                g.DrawString(" (  @  ) ", fMiniEye, sb, ex - 28 + ox, ey - 2);
                g.DrawString("  '---'  ", fMiniEye, sb, ex - 28, ey + 6);
            }
        }
    }

    private void PaintSmoothEyeGlow(Graphics g)
    {
        if (T < 4f) return;
        int rx = Math.Max(260, (int)(W / 4 * eyeLunge));
        int ry = (int)(rx * 0.52f);
        using (GraphicsPath gp = new GraphicsPath())
        {
            gp.AddEllipse(CX - rx, CY - ry, rx * 2, ry * 2);
            try
            {
                using (PathGradientBrush pgb = new PathGradientBrush(gp))
                {
                    Color gc = Lerp(Color.FromArgb(0, 120, 255), Color.FromArgb(165, 0, 0), colorMix);
                    int alpha = (T < 7f) ? (int)((T - 4f) / 3f * 45) : 55 + (int)(Math.Sin(T * 2.2) * 14);
                    pgb.CenterColor    = Color.FromArgb(Clamp(alpha, 0, 80), gc);
                    pgb.SurroundColors = new Color[] { Color.FromArgb(0, 0, 0, 0) };
                    g.FillPath(pgb, gp);
                }
            }
            catch {}
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  DRAW: VIBRANT ICE-BLUE -> BLOOD-RED ASCII EYE
    // ═══════════════════════════════════════════════════════════════════
    private void PaintAsciiEye(Graphics g)
    {
        if (T < 4f) return;
        eyeSpawnPts.Clear();

        int cols = 64, rows = 27;
        float cw = 8.6f * eyeLunge, ch = 12.2f * eyeLunge;
        float startX = CX - (cols * cw) / 2f;
        float startY = CY - (rows * ch) / 2f;

        float halfW = cols / 2f;
        float openFactor = (T < 7.0f) ? 0.15f : Math.Max(0.08f, eyeOpen);
        float maxHalfH = (rows / 2f) * 0.84f * openFactor;
        float outlineProg = (T < 7.0f) ? Cf((T - 4f) / 3.0f, 0f, 1f) : 1f;

        Color irisOuter = Lerp(Color.FromArgb(0, 100, 255),  Color.FromArgb(175, 0, 0),  colorMix);
        Color irisInner = Lerp(Color.FromArgb(95, 230, 255), Color.FromArgb(255, 35, 15), colorMix);

        float pupilPulse = (1f + (float)Math.Sin(T * 2.0) * 0.05f) * pupilScale;
        float irisR  = 7.0f;
        float pupilR = Cf(2.70f * pupilPulse, 1.4f, 4.7f);

        string irisChars   = "@#%01*+";
        string scleraChars = ".:;·";

        int chromaOff = (glitchLvl > 0.25f && R.NextDouble() < 0.24) ? R.Next(2, 7) : 0;
        int tearRow1  = (glitchLvl > 0.25f && R.NextDouble() < 0.40) ? R.Next(rows) : -1;
        float tearOff1 = (float)(R.NextDouble() - 0.5) * 24f;

        for (int r = 0; r < rows; r++)
        {
            float dy = r - rows / 2f;
            float rowTear = (r == tearRow1) ? tearOff1 : 0f;

            for (int c = 0; c < cols; c++)
            {
                float dx = c - halfW;
                float nx = dx / halfW;
                if (Math.Abs(nx) > 1.0f) continue;

                float lid = (float)Math.Pow(1.0f - nx * nx, 0.85) * maxHalfH;
                float distToLid = Math.Abs(Math.Abs(dy) - lid);

                float px = startX + c * cw + rowTear;
                float py = startY + r * ch;

                if (T < 7.0f)
                {
                    if (distToLid < 0.80f)
                    {
                        int a = Clamp((int)(outlineProg * 210), 0, 255);
                        string glyph = (distToLid < 0.4f) ? "\u2593" : "\u2591";
                        using (SolidBrush b = new SolidBrush(Color.FromArgb(a, 0, 165, 255)))
                            g.DrawString(glyph, fEye, b, px, py);
                    }
                    continue;
                }

                if (distToLid < 0.72f)
                {
                    Color lc = Lerp(Color.FromArgb(0, 175, 255), Color.FromArgb(145, 12, 12), colorMix);
                    string lidChar = (Math.Abs(nx) > 0.85f) ? (nx < 0 ? "<" : ">") : ((dy < 0) ? "\u2580" : "\u2584");
                    using (SolidBrush b = new SolidBrush(Color.FromArgb(235, lc)))
                        g.DrawString(lidChar, fEye, b, px, py);

                    if (dy >= 0 && Math.Abs(nx) < 0.88f)
                        eyeSpawnPts.Add(new float[] { px + cw * 0.5f, py + ch * 0.65f });
                    continue;
                }

                if (Math.Abs(dy) > lid)
                {
                    if (veinA > 0.05f && Math.Abs(dy) < lid + 4.2f)
                    {
                        double vNoise = Math.Sin(c * 0.85 + r * 1.4 + T * 0.2) * Math.Cos(c * 0.35 - r * 0.75);
                        if (vNoise > 0.50)
                        {
                            int va = Clamp((int)(veinA * 180), 0, 255);
                            string vChar = (vNoise > 0.74) ? "~" : ((dx * dy > 0) ? "\\" : "/");
                            using (SolidBrush vb = new SolidBrush(Color.FromArgb(va, 165, 0, 0)))
                                g.DrawString(vChar, fEye, vb, px, py);
                        }
                    }
                    continue;
                }

                float pdx = (dx - lookX) * 0.70f;
                float pdy = (dy - lookY);
                float dist = (float)Math.Sqrt(pdx * pdx + pdy * pdy);

                if (dist < pupilR)
                {
                    if (Math.Abs(pdx + 1.0f) < 0.55f && Math.Abs(pdy + 0.8f) < 0.55f)
                    {
                        using (SolidBrush hb = new SolidBrush(Color.FromArgb(220, 240, 250, 255)))
                            g.DrawString("\u00B0", fEye, hb, px, py);
                    }
                }
                else if (dist < irisR)
                {
                    float tRad = Cf((dist - pupilR) / (irisR - pupilR), 0f, 1f);
                    Color ic = Lerp(irisInner, irisOuter, tRad);
                    double ang = Math.Atan2(pdy, pdx) + T * 0.35;
                    int idx = Math.Abs((int)(ang * 7.5 + dist * 1.6)) % irisChars.Length;
                    string chIris = irisChars[idx].ToString();

                    if (chromaOff > 0)
                    {
                        using (SolidBrush rb = new SolidBrush(Color.FromArgb(110, 230, 0, 0)))
                            g.DrawString(chIris, fEye, rb, px - chromaOff, py);
                    }
                    using (SolidBrush ib = new SolidBrush(Color.FromArgb(245, ic)))
                        g.DrawString(chIris, fEye, ib, px, py);
                }
                else
                {
                    double vSclera = Math.Sin(c * 1.3 + r * 0.95) * Math.Cos(c * 0.4 + r * 0.5);
                    if (veinA > 0.1f && vSclera > 0.58)
                    {
                        int va = Clamp((int)(veinA * 220), 0, 255);
                        using (SolidBrush vb = new SolidBrush(Color.FromArgb(va, 175, 0, 0)))
                            g.DrawString("~", fEye, vb, px, py);
                    }
                    else
                    {
                        int sR = Clamp((int)(195 - colorMix * 15), 0, 255);
                        int sG = Clamp((int)(205 - colorMix * 52), 0, 255);
                        int sB = Clamp((int)(215 - colorMix * 62), 0, 255);
                        string scChar = scleraChars[(c + r) % scleraChars.Length].ToString();
                        using (SolidBrush sb = new SolidBrush(Color.FromArgb(185, sR, sG, sB)))
                            g.DrawString(scChar, fEye, sb, px, py);
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  DRAW: SCARE FLASH, BLOOD, DIGITAL ROT, GLITCHES, VIGNETTE
    // ═══════════════════════════════════════════════════════════════════
    private void PaintScareFlash(Graphics g)
    {
        g.Clear(Color.FromArgb(20, 0, 0));
        string line1 = "        @ @ # # # % % @ @        ";
        string line2 = "    @ # 0 1 @ @     @ @ 1 0 # @  ";
        string line3 = "  # 0 1 @ @             @ @ 1 0 #";
        int jx = R.Next(-18, 19), jy = R.Next(-12, 13);
        using (SolidBrush b = new SolidBrush(Color.FromArgb(225, 205, 0, 0)))
        {
            g.DrawString(line1, fBig, b, CX - 420 + jx, CY - 140 + jy);
            g.DrawString(line2, fBig, b, CX - 420 + jx, CY - 50 + jy);
            g.DrawString(line3, fBig, b, CX - 420 + jx, CY + 40 + jy);
            g.DrawString(line2, fBig, b, CX - 420 + jx, CY + 130 + jy);
        }
        PaintHeartbeatVignette(g);
    }

    private void PaintBlood(Graphics g)
    {
        for (int i = 0; i < blood.Count; i++)
        {
            float[] d = blood[i];
            float bx = d[0], by = d[1], sz = d[3], tr = d[4];
            int a = Clamp((int)(d[5] - Math.Max(0, by - CY) * 0.20f), 25, 235);
            using (LinearGradientBrush lg = new LinearGradientBrush(
                new PointF(bx, by - tr), new PointF(bx, by + 1),
                Color.FromArgb(0, 80, 0, 0), Color.FromArgb(a, 165, 0, 0)))
            {
                using (Pen tp = new Pen(lg, Math.Max(1.8f, sz * 0.60f)))
                    g.DrawLine(tp, bx, by - tr, bx, by);
            }
            using (SolidBrush db = new SolidBrush(Color.FromArgb(a, 185, 0, 0)))
                g.FillEllipse(db, bx - sz * 0.5f, by - sz * 0.5f, sz, sz * 1.55f);
        }
    }

    private void PaintDigitalRot(Graphics g)
    {
        if (T < 24f) return;
        int blocks = Clamp((int)((T - 24f) * 2.5f), 4, 38);
        for (int i = 0; i < blocks; i++)
        {
            if (R.NextDouble() > 0.45) continue;
            bool leftSide = R.Next(2) == 0;
            int rx = leftSide ? R.Next(0, Math.Max(20, W / 6)) : R.Next(W - Math.Max(20, W / 6), W);
            int ry = R.Next(H), rw = R.Next(8, 36), rh = R.Next(3, 14);
            Color rc = (R.Next(3) == 0) ? Color.FromArgb(95, 160, 0, 0) : Color.FromArgb(65, 90, 90, 90);
            using (SolidBrush b = new SolidBrush(rc))
                g.FillRectangle(b, rx, ry, rw, rh);
        }
    }

    private void PaintVhsGlitches(Graphics g)
    {
        if (glitchLvl < 0.02f) return;
        int bars = 1 + (int)(glitchLvl * 4);
        for (int i = 0; i < bars; i++)
        {
            if (R.NextDouble() > glitchLvl * 0.75) continue;
            int gy = R.Next(H), gh = R.Next(1, 16), a = R.Next(14, 48);
            Color gc = (R.Next(3) == 0) ? Color.FromArgb(a, 190, 20, 20) : Color.FromArgb(a, 195, 195, 195);
            using (SolidBrush b = new SolidBrush(gc))
                g.FillRectangle(b, 0, gy, W, gh);
        }
        int specks = (int)(glitchLvl * 42);
        using (SolidBrush sb = new SolidBrush(Color.FromArgb(70, 205, 205, 205)))
        {
            for (int i = 0; i < specks; i++)
                g.FillRectangle(sb, R.Next(W), R.Next(H), R.Next(2, 9), 1);
        }
    }

    private void PaintHeartbeatVignette(Graphics g)
    {
        using (Pen p = new Pen(Color.FromArgb(26, 0, 0, 0), 1))
            for (int y = 0; y < H; y += 3)
                g.DrawLine(p, 0, y, W, y);

        int vw = W / 8;
        float pulse = (T > 20f) ? (float)Math.Max(0.0, Math.Sin(T * 5.7)) : 0f;
        Color edgeCol = Color.FromArgb(215, (int)(55 * pulse * colorMix), 0, 0);

        using (LinearGradientBrush lb = new LinearGradientBrush(
            new Rectangle(0, 0, vw, H), edgeCol, Color.FromArgb(0, 0, 0, 0), 0f))
            g.FillRectangle(lb, 0, 0, vw, H);
        using (LinearGradientBrush rb = new LinearGradientBrush(
            new Rectangle(W - vw, 0, vw, H), Color.FromArgb(0, 0, 0, 0), edgeCol, 0f))
            g.FillRectangle(rb, W - vw, 0, vw, H);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  DRAW: SIDEBAR, MESSAGES, NOTEPADS, POPUPS, DIALOG, HUD
    // ═══════════════════════════════════════════════════════════════════
    private void PaintSidebar(Graphics g)
    {
        float y0 = H * 0.25f;
        for (int i = 0; i < sbCount; i++)
        {
            float dt = T - sbShow[i];
            if (dt < 0) continue;
            float alpha = (T > 39.5f) ? Math.Max(0f, 1f - (T - 39.5f)) : 1f;
            if (alpha < 0.01f) continue;
            int ch = Math.Min((int)(dt * 26), sbText[i].Length);
            string vis = sbText[i].Substring(0, ch);
            Color c = Color.FromArgb(Clamp((int)(alpha * 205), 0, 255), sbR[i], sbG[i], sbB[i]);
            using (SolidBrush b = new SolidBrush(c))
                g.DrawString(vis, fDiag, b, 24, y0 + i * 22);
        }
    }

    private void PaintMsgs(Graphics g)
    {
        for (int i = 0; i < mCount; i++)
        {
            if (string.IsNullOrEmpty(mText[i])) continue;
            float dt = T - mShow[i];
            if (dt < 0 || dt > mDur[i]) continue;

            float alpha = 1f;
            if (dt < 0.5f) alpha = dt / 0.5f;
            if (dt > mDur[i] - 1.0f) alpha = Math.Min(alpha, (mDur[i] - dt) / 1.0f);
            alpha = Cf(alpha, 0f, 1f);

            string text = mText[i];
            Font font   = mBig[i] ? fBig : fMsg;
            float jx = 0, jy = 0;

            if (mFx[i] == 0)
            {
                int ch = (int)(dt * 14);
                if (ch < text.Length) text = text.Substring(0, ch) + (((int)(T * 4) % 2 == 0) ? "_" : "");
            }
            else if (mFx[i] == 1 && R.NextDouble() < 0.14)
            {
                jx = (float)(R.NextDouble() - 0.5) * 4;
                jy = (float)(R.NextDouble() - 0.5) * 2;
            }

            int ca = Clamp((int)(alpha * 245), 0, 255);
            SizeF sz = g.MeasureString(text, font);
            using (SolidBrush b = new SolidBrush(Color.FromArgb(ca, mR[i], mG[i], mB[i])))
                g.DrawString(text, font, b, (W - sz.Width) / 2 + jx, H * mRelY[i] + jy);
        }
    }

    private void PaintNpads(Graphics g)
    {
        for (int i = 0; i < npCount; i++)
        {
            float a = FadeWin(npShow[i], npFade[i]);
            if (a < 0.01f) continue;
            int x = npX[i], y = npY[i], w = npW[i], h = npH[i];

            using (SolidBrush s = new SolidBrush(Color.FromArgb(Clamp((int)(75 * a),0,255), 0, 0, 0)))
                g.FillRectangle(s, x + 5, y + 5, w, h);
            using (SolidBrush wb = new SolidBrush(Color.FromArgb(Clamp((int)(255*a),0,255), 255, 255, 255)))
                g.FillRectangle(wb, x, y, w, h);
            using (SolidBrush tb = new SolidBrush(Color.FromArgb(Clamp((int)(255*a),0,255), 240, 240, 240)))
                g.FillRectangle(tb, x, y, w, 28);
            using (SolidBrush tt = new SolidBrush(Color.FromArgb(Clamp((int)(230*a),0,255), 20, 20, 20)))
                g.DrawString(npTtl[i], fTitle, tt, x + 8, y + 6);
            using (Pen xp = new Pen(Color.FromArgb(Clamp((int)(180*a),0,255), 60, 60, 60), 1.3f))
            {
                g.DrawLine(xp, x + w - 24, y + 9, x + w - 14, y + 19);
                g.DrawLine(xp, x + w - 24, y + 19, x + w - 14, y + 9);
            }
            using (SolidBrush mt = new SolidBrush(Color.FromArgb(Clamp((int)(150*a),0,255), 40, 40, 40)))
                g.DrawString("Bestand  Bewerken  Opmaak  Beeld  Help", fSmall, mt, x + 6, y + 30);
            using (Pen sep = new Pen(Color.FromArgb(Clamp((int)(90*a),0,255), 190, 190, 190), 1))
                g.DrawLine(sep, x, y + 48, x + w, y + 48);

            float dt = Math.Max(0f, T - npShow[i] - 0.25f);
            int chars = Math.Min((int)(dt * npRate[i]), npBdy[i].Length);
            string typed = npBdy[i].Substring(0, chars);
            if ((int)(T * 2.5) % 2 == 0) typed += "|";

            using (SolidBrush ct = new SolidBrush(Color.FromArgb(Clamp((int)(235*a),0,255), 15, 15, 15)))
                g.DrawString(typed, fNote, ct, x + 8, y + 56);
            using (Pen bp = new Pen(Color.FromArgb(Clamp((int)(180*a),0,255), 110, 110, 110), 1))
                g.DrawRectangle(bp, x, y, w, h);
        }
    }

    private void PaintErrorPopups(Graphics g)
    {
        for (int i = 0; i < erCount; i++)
        {
            float a = FadeWin(erShow[i], erFade[i]);
            if (a < 0.01f) continue;
            int x = erX[i], y = erY[i], w = 310, h = 115;

            using (SolidBrush bg = new SolidBrush(Color.FromArgb(Clamp((int)(248*a),0,255), 242, 242, 242)))
                g.FillRectangle(bg, x, y, w, h);
            using (Pen bp = new Pen(Color.FromArgb(Clamp((int)(170*a),0,255), 120, 120, 120), 1))
                g.DrawRectangle(bp, x, y, w, h);
            using (SolidBrush tb = new SolidBrush(Color.FromArgb(Clamp((int)(255*a),0,255), 255, 255, 255)))
                g.FillRectangle(tb, x + 1, y + 1, w - 2, 26);
            using (SolidBrush tt = new SolidBrush(Color.FromArgb(Clamp((int)(240*a),0,255), 15, 15, 15)))
                g.DrawString(erTtl[i], fTitle, tt, x + 8, y + 5);

            using (SolidBrush rb = new SolidBrush(Color.FromArgb(Clamp((int)(245*a),0,255), 200, 20, 20)))
                g.FillEllipse(rb, x + 16, y + 42, 24, 24);
            using (Pen xp = new Pen(Color.FromArgb(Clamp((int)(255*a),0,255), 255, 255, 255), 2f))
            {
                g.DrawLine(xp, x + 23, y + 49, x + 33, y + 59);
                g.DrawLine(xp, x + 23, y + 59, x + 33, y + 49);
            }
            using (SolidBrush bt = new SolidBrush(Color.FromArgb(Clamp((int)(240*a),0,255), 20, 20, 20)))
                g.DrawString(erBdy[i], fTitle, bt, x + 50, y + 46);
            DrawWinBtn(g, x + w - 92, y + 78, 76, 24, "OK", false);
        }
    }

    private void PaintHijackedDialog(Graphics g)
    {
        if (T < 28.0f || T > 35.0f) return;
        int w = 345, h = 148, x = W - w - 34, y = H - h - 42;
        bool morphed = (T >= 29.8f);

        using (SolidBrush bg = new SolidBrush(Color.FromArgb(245, 240, 240, 240)))
            g.FillRectangle(bg, x, y, w, h);
        using (Pen bp = new Pen(Color.FromArgb(140, 140, 140), 1))
            g.DrawRectangle(bp, x, y, w, h);
        using (SolidBrush tb = new SolidBrush(Color.FromArgb(255, 255, 255)))
            g.FillRectangle(tb, x + 1, y + 1, w - 2, 28);
        using (SolidBrush tt = new SolidBrush(Color.Black))
            g.DrawString("ARON.exe reageert niet", fTitle, tt, x + 10, y + 6);

        string body = morphed ? "het helpt niet.\r\nblijf kijken."
                              : "Als u het programma sluit, gaan gegevens\r\nmogelijk verloren.";
        using (SolidBrush bt = new SolidBrush(morphed ? Color.FromArgb(165, 0, 0) : Color.FromArgb(30, 30, 30)))
            g.DrawString(body, fTitle, bt, x + 14, y + 42);

        DrawWinBtn(g, x + 20,  y + 104, 140, 28, morphed ? "het helpt niet" : "Programma sluiten", morphed);
        DrawWinBtn(g, x + 174, y + 104, 148, 28, morphed ? "blijf kijken"   : "Wachten op reactie", morphed);
    }

    private void DrawWinBtn(Graphics g, int x, int y, int w, int h, string txt, bool red)
    {
        using (SolidBrush bg = new SolidBrush(Color.FromArgb(225, 225, 225)))
            g.FillRectangle(bg, x, y, w, h);
        using (Pen bp = new Pen(Color.FromArgb(160, 160, 160), 1))
            g.DrawRectangle(bp, x, y, w, h);
        using (SolidBrush tb = new SolidBrush(red ? Color.FromArgb(150, 0, 0) : Color.Black))
            g.DrawString(txt, fSmall, tb, x + 10, y + 6);
    }

    private float FadeWin(float show, float fade)
    {
        if (T < show) return 0f;
        float dt = T - show;
        if (dt < 0.25f) return dt / 0.25f;
        if (T < fade) return 1f;
        float ft = T - fade;
        if (ft < 0.6f) return 1f - ft / 0.6f;
        return 0f;
    }

    private void PaintViewfinder(Graphics g)
    {
        int inset = 22 + (int)(Math.Min(T, 30f) * 0.5f), len = 28;
        Color vc = Lerp(Color.FromArgb(90, 140, 180), Color.FromArgb(170, 20, 20), colorMix);
        using (Pen vp = new Pen(vc, 1.5f))
        {
            g.DrawLine(vp, inset, inset, inset + len, inset);
            g.DrawLine(vp, inset, inset, inset, inset + len);
            g.DrawLine(vp, W - inset, inset, W - inset - len, inset);
            g.DrawLine(vp, W - inset, inset, W - inset, inset + len);
            g.DrawLine(vp, inset, H - inset, inset + len, H - inset);
            g.DrawLine(vp, inset, H - inset, inset, H - inset - len);
            g.DrawLine(vp, W - inset, H - inset, W - inset - len, H - inset);
            g.DrawLine(vp, W - inset, H - inset, W - inset, H - inset - len);
        }
    }

    private void PaintExitReaction(Graphics g)
    {
        if (!mouseNearExit) return;
        string warn = (T > 20f) ? "probeer het maar." : "waar ga je naartoe.";
        using (SolidBrush b = new SolidBrush(Color.FromArgb(220, 210, 25, 25)))
            g.DrawString(warn, fDiag, b, W - 235, 42);
    }

    private void PaintVhsHud(Graphics g)
    {
        if (((int)(T * 2)) % 2 == 0)
        {
            using (SolidBrush rb = new SolidBrush(Color.FromArgb(200, 195, 0, 0)))
                g.FillEllipse(rb, 28, 16, 10, 10);
        }
        string clockStr = (T < 24.5f)
            ? realStart.AddSeconds((int)T).ToString("HH:mm:ss")
            : "03:14:00  [TIJD BEVROREN]";
        using (SolidBrush vb = new SolidBrush(Color.FromArgb(175, 205, 205, 205)))
            g.DrawString("OPNAME  " + clockStr, fVhs, vb, 44, 13);

        if (T >= 15.8f && T < 17.8f)
        {
            using (SolidBrush sb = new SolidBrush(Color.FromArgb(190, 220, 220, 220)))
                g.DrawString("opgeslagen.", fDiag, sb, 28, 36);
        }
    }

    private void PaintUI(Graphics g)
    {
        int bx = W - 94, by = 10, bw = 82, bh = 24;
        using (SolidBrush bg = new SolidBrush(Color.FromArgb(70, 35, 35, 35)))
            g.FillRectangle(bg, bx, by, bw, bh);
        using (Pen bp = new Pen(Color.FromArgb(95, 145, 145, 145), 1))
            g.DrawRectangle(bp, bx, by, bw, bh);
        using (SolidBrush bt = new SolidBrush(Color.FromArgb(155, 205, 205, 205)))
            g.DrawString("[ESC] Sluiten", fSmall, bt, bx + 5, by + 5);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  UTILITIES & CLEAN EXIT
    // ═══════════════════════════════════════════════════════════════════
    private Color Lerp(Color a, Color b, float t)
    {
        t = Cf(t, 0f, 1f);
        return Color.FromArgb(
            a.R + (int)((b.R - a.R) * t),
            a.G + (int)((b.G - a.G) * t),
            a.B + (int)((b.B - a.B) * t));
    }
    private static int Clamp(int v, int lo, int hi) { return v < lo ? lo : (v > hi ? hi : v); }
    private static float Cf(float v, float lo, float hi) { return v < lo ? lo : (v > hi ? hi : v); }

    private void TriggerExit()
    {
        if (closing) { ForceClose(); return; }
        closing = true;
        closeStart = T;
        SetAudioStage(5); // CRT power-down thud
    }

    private void ForceClose()
    {
        ExitRequested = true;
        if (tmr != null) { tmr.Stop(); tmr.Dispose(); tmr = null; }
        if (calmPlayer      != null) { try { calmPlayer.Stop();      } catch {} }
        if (tensePlayer     != null) { try { tensePlayer.Stop();     } catch {} }
        if (screechPlayer   != null) { try { screechPlayer.Stop();   } catch {} }
        if (pitchDropPlayer != null) { try { pitchDropPlayer.Stop(); } catch {} }
        if (powerDownPlayer != null) { try { powerDownPlayer.Stop(); } catch {} }
        try { this.Close(); } catch {}
    }

    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        if (tmr != null) { tmr.Stop(); tmr.Dispose(); tmr = null; }
        if (calmPlayer      != null) { try { calmPlayer.Stop();      calmPlayer.Dispose();      } catch {} calmPlayer = null; }
        if (tensePlayer     != null) { try { tensePlayer.Stop();     tensePlayer.Dispose();     } catch {} tensePlayer = null; }
        if (screechPlayer   != null) { try { screechPlayer.Stop();   screechPlayer.Dispose();   } catch {} screechPlayer = null; }
        if (pitchDropPlayer != null) { try { pitchDropPlayer.Stop(); pitchDropPlayer.Dispose(); } catch {} pitchDropPlayer = null; }
        if (powerDownPlayer != null) { try { powerDownPlayer.Stop(); powerDownPlayer.Dispose(); } catch {} powerDownPlayer = null; }
        if (calmStream      != null) { try { calmStream.Dispose();      } catch {} calmStream = null; }
        if (tenseStream     != null) { try { tenseStream.Dispose();     } catch {} tenseStream = null; }
        if (screechStream   != null) { try { screechStream.Dispose();   } catch {} screechStream = null; }
        if (pitchDropStream != null) { try { pitchDropStream.Dispose(); } catch {} pitchDropStream = null; }
        if (powerDownStream != null) { try { powerDownStream.Dispose(); } catch {} powerDownStream = null; }
        if (fStream  != null) fStream.Dispose();
        if (fEye     != null) fEye.Dispose();
        if (fMiniEye != null) fMiniEye.Dispose();
        if (fMsg     != null) fMsg.Dispose();
        if (fBig     != null) fBig.Dispose();
        if (fNote    != null) fNote.Dispose();
        if (fTitle   != null) fTitle.Dispose();
        if (fDiag    != null) fDiag.Dispose();
        if (fSmall   != null) fSmall.Dispose();
        if (fVhs     != null) fVhs.Dispose();
        if (fHuge    != null) fHuge.Dispose();
        if (fBsodBig != null) fBsodBig.Dispose();
        if (fBsodTxt != null) fBsodTxt.Dispose();
        base.OnFormClosed(e);
    }
}
}
'@

try {
    if (-not ('AronEye.AronForm' -as [type])) {
        $refs = @(
            [System.Windows.Forms.Form].Assembly.Location
            [System.Drawing.Bitmap].Assembly.Location
            [System.Media.SoundPlayer].Assembly.Location
        )
        Add-Type -TypeDefinition $cs -ReferencedAssemblies $refs -ErrorAction Stop
    }

    [System.Windows.Forms.Application]::EnableVisualStyles()
    $form = New-Object AronEye.AronForm
    [System.Windows.Forms.Application]::Run($form)
    $shouldExit = $form.ExitRequested
    $form.Dispose()

    if ($shouldExit) {
        $notePath = Join-Path $env:TEMP "aron_note.txt"
        Set-Content -Path $notePath -Value "je bent nog niet veilig." -Encoding UTF8
        Start-Process notepad.exe -ArgumentList $notePath
        [Environment]::Exit(0)
    }
}
catch {
    Write-Host ""
    Write-Host "  ARON.exe - ERROR" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Press any key..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}
}
