using UnityEngine;
using System.Collections;
using System.IO;

public class Screenshot : MonoBehaviour
{
    public int supersampling = 4;

    void Update()
    {
        if (Input.GetKeyDown(KeyCode.P))
            Capture();

    }

    void Capture()
    {
        int num = 0;

        string fileName = "screen_";
        string ext = ".png";

        while (File.Exists(fileName + num + ext))
        {
            num++;

            if (num > 10000) break;
        }

        Application.CaptureScreenshot(fileName + num + ext, supersampling);

        Debug.Log("Screen captured: " + fileName + num + ext);
    }
}
