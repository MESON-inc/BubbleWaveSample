using System.Threading;
using Cysharp.Threading.Tasks;
using UnityEngine;
using UnityEngine.InputSystem;

namespace BubbleWave
{
    public class DomeWaveAnimator : MonoBehaviour
    {
        [SerializeField] private Renderer _renderer;
        [SerializeField] private float _startDuration = 0.5f;
        [SerializeField] private float _endDuration = 3.0f;
        [SerializeField] private Camera _camera;

        private Material _material;
        private static readonly int s_reverseMaskDistance = Shader.PropertyToID("_ReverseMaskDistance");
        private static readonly int s_maskDistance = Shader.PropertyToID("_MaskDistance");
        private static readonly int s_centerVector = Shader.PropertyToID("_CenterVector");

        private CancellationTokenSource _animationCts;

        private void Awake()
        {
            _material = _renderer.material;
        }

        private void Update()
        {
            if (Mouse.current.leftButton.wasPressedThisFrame)
            {
                Vector3 screenPosition = Mouse.current.position.ReadValue();
                screenPosition.z = _camera.nearClipPlane;
                Raycast(screenPosition);
            }
        }

        private void OnDestroy()
        {
            if (_material != null)
            {
                Destroy(_material);
            }
        }

        private void ResetAnimation()
        {
            _material.SetFloat(s_maskDistance, 0);
            _material.SetFloat(s_reverseMaskDistance, 0);
            
            if (_animationCts != null)
            {
                _animationCts.Cancel();
                _animationCts.Dispose();
            }

            _animationCts = CancellationTokenSource.CreateLinkedTokenSource(destroyCancellationToken);
        }

        private float Easing(float x)
        {
            return Mathf.Pow(x, 2f);
        }

        /// <summary>
        /// Editor上でのデバッグ用メソッド
        /// Gameビューで触れた位置に波紋を表示する
        /// </summary>
        /// <param name="screenPosition">クリック位置</param>
        private void Raycast(Vector3 screenPosition)
        {
            if (_camera == null) return;

            screenPosition.z = _camera.nearClipPlane;

            Ray ray = _camera.ScreenPointToRay(screenPosition);

            if (Physics.Raycast(ray, out RaycastHit hitInfo))
            {
                if (hitInfo.collider.gameObject == _renderer.gameObject)
                {
                    ResetAnimation();
                    Vector3 pos = _renderer.transform.InverseTransformPoint(hitInfo.point);
                    SetCenterVector(pos);
                    WaveAsync(_animationCts.Token).Forget();
                }
            }
        }

        private void SetCenterVector(Vector3 centerVector)
        {
            _material.SetVector(s_centerVector, centerVector);
        }

        public async UniTask WaveAsync(CancellationToken cancellationToken = default)
        {
            float ratio = 0.3f;
            float time = 0;
            while (time < _startDuration)
            {
                if (cancellationToken.IsCancellationRequested) break;

                float x = time / _startDuration;
                float t = Easing(x);
                _material.SetFloat(s_maskDistance, t);
                time += Time.deltaTime;
                await UniTask.Yield(PlayerLoopTiming.Update, cancellationToken);
            }

            time = 0;
            while (time < _endDuration)
            {
                if (cancellationToken.IsCancellationRequested) break;

                float x = time / _endDuration;
                float t = Easing(x);
                _material.SetFloat(s_reverseMaskDistance, t);
                time += Time.deltaTime;
                await UniTask.Yield(PlayerLoopTiming.Update, cancellationToken);
            }

            _material.SetFloat(s_maskDistance, 0);
            _material.SetFloat(s_reverseMaskDistance, 0);
        }
    }
}