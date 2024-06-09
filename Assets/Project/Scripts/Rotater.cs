using UnityEngine;

public class Rotater : MonoBehaviour
{
    [SerializeField] private float _speed = 10f;
    
    private float _angle = 0;
    private Quaternion _initRot;

    private void Awake()
    {
        _initRot = transform.rotation;
    }

    private void Update()
    {
        _angle += Time.deltaTime * _speed;
        float r = Mathf.Sin(_angle * Mathf.Deg2Rad);
        transform.rotation = _initRot * Quaternion.Euler(0, r * 180f, 0);
    }
}
