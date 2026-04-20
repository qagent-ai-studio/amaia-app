package com.mistatas.amaia.ble

import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import com.moko.ble.lib.MokoConstants
import com.moko.ble.lib.event.ConnectStatusEvent
import com.moko.ble.lib.event.OrderTaskResponseEvent
import com.moko.support.d.DMokoSupport
import com.moko.support.d.OrderTaskAssembler
import com.moko.support.d.entity.OrderCHAR
import org.greenrobot.eventbus.EventBus
import org.greenrobot.eventbus.Subscribe
import org.greenrobot.eventbus.ThreadMode

class TestMkButtonActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "TestMkButton"
        const val EXTRA_MAC_ADDRESS = "extra_mac_address"
    }

    private var deviceMac: String = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        deviceMac = intent.getStringExtra(EXTRA_MAC_ADDRESS) ?: ""
        if (deviceMac.isEmpty()) {
            Log.e(TAG, "MAC address is required")
            finish()
            return
        }

        Log.d(TAG, "Starting test connection to: $deviceMac")

        DMokoSupport.getInstance().init(applicationContext)
    }

    override fun onStart() {
        super.onStart()
        EventBus.getDefault().register(this)

        Log.d(TAG, "Calling connDevice()")
        DMokoSupport.getInstance().connDevice(deviceMac)
    }

    override fun onStop() {
        super.onStop()
        EventBus.getDefault().unregister(this)

        DMokoSupport.getInstance().disConnectBle()
    }

    @Subscribe(threadMode = ThreadMode.MAIN)
    fun onConnectStatusEvent(event: ConnectStatusEvent) {
        val action = event.action
        Log.d(TAG, "ConnectStatusEvent: $action")

        when (action) {
            MokoConstants.ACTION_DISCONNECTED -> {
                Log.e(TAG, "Device disconnected")

            }
            MokoConstants.ACTION_DISCOVER_SUCCESS -> {
                Log.i(TAG, "Device connected successfully!")

                readDeviceInfo()
            }
        }
    }

    @Subscribe(threadMode = ThreadMode.MAIN)
    fun onOrderTaskResponseEvent(event: OrderTaskResponseEvent) {
        val action = event.action
        Log.d(TAG, "OrderTaskResponseEvent: $action")

        when (action) {
            MokoConstants.ACTION_ORDER_TIMEOUT -> {
                val response = event.response
                Log.e(TAG, "Order timeout for: ${response?.orderCHAR}")
            }
            MokoConstants.ACTION_ORDER_FINISH -> {
                Log.i(TAG, "All orders finished")
            }
            MokoConstants.ACTION_ORDER_RESULT -> {
                val response = event.response ?: return
                handleOrderResult(response)
            }
            MokoConstants.ACTION_CURRENT_DATA -> {
                val response = event.response ?: return
                handleNotifyData(response)
            }
        }
    }

    private fun readDeviceInfo() {
        Log.d(TAG, "Reading device info using sendOrder()")

        DMokoSupport.getInstance().sendOrder(
            OrderTaskAssembler.getBatteryPercent(),
            OrderTaskAssembler.getDeviceName()
        )
    }

    private fun handleOrderResult(response: com.moko.ble.lib.task.OrderTaskResponse) {
        val orderCHAR = response.orderCHAR as? OrderCHAR ?: return
        val value = response.responseValue

        Log.d(TAG, "Order result for: $orderCHAR, value size: ${value?.size ?: 0}")

        when (orderCHAR) {
            OrderCHAR.CHAR_PARAMS -> {

                if (value != null && value.isNotEmpty()) {
                    val battery = value[0].toInt() and 0xFF
                    Log.i(TAG, "Battery: $battery%")
                }
            }
            OrderCHAR.CHAR_MODEL_NUMBER -> {

                if (value != null) {
                    val name = String(value)
                    Log.i(TAG, "Device name: $name")
                }
            }
            else -> {
                Log.d(TAG, "Unhandled order: $orderCHAR")
            }
        }
    }

    private fun handleNotifyData(response: com.moko.ble.lib.task.OrderTaskResponse) {
        val orderCHAR = response.orderCHAR as? OrderCHAR ?: return
        val value = response.responseValue

        Log.d(TAG, "Notify data for: $orderCHAR")

    }
}
