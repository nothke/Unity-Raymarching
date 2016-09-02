using UnityEngine;
using System.Collections;

public class Flycam : MonoBehaviour
{

    public float speed;

    bool slow;
    bool fast;

    void Start()
    {

    }

    float GetAxis(KeyCode keyNegative, KeyCode keyPositive)
    {
        return Input.GetKey(keyNegative) ? -1 : Input.GetKey(keyPositive) ? 1 : 0;
    }

    void Update()
    {
        float horizontal = GetAxis(KeyCode.A, KeyCode.D);
        float forward = GetAxis(KeyCode.S, KeyCode.W);
        float vertical = GetAxis(KeyCode.C, KeyCode.X);
        


        Vector3 input = new Vector3(horizontal, vertical, forward);


        transform.Translate(input * Time.deltaTime, Space.Self);

        transform.Rotate(-Input.GetAxis("Mouse Y"), Input.GetAxis("Mouse X"), 0, Space.Self);
    }
}
